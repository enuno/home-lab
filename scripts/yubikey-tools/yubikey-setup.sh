#!/usr/bin/env bash

################################################################################
# YubiKey SSH and GPG Key Management Script
#
# Purpose: Automate YubiKey 5 NFC configuration for SSH authentication and
#          GPG code signing with support for both new key generation and
#          loading pre-existing keys.
#
# Author: Automated by AI Assistant
# Version: 1.1.0
# Date: 2025-10-26
# Repository: https://github.com/enuno/home-lab/scripts/
################################################################################

set -euo pipefail

################################################################################
# Global Variables
################################################################################

SCRIPT_VERSION="1.1.0"
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/tmp/yubikey-setup-$(date +%Y%m%d-%H%M%S).log"
BACKUP_BASE_DIR="${HOME}/yubikey-backups"

# Operation mode
MODE=""
OPERATION_MODE=""

# User information
CARDHOLDER_NAME=""
CARDHOLDER_EMAIL=""

# Configuration options
KEY_TYPE="rsa4096"
TOUCH_POLICY="on"
SKIP_SSH=false
SKIP_GIT=false
NO_BACKUP=false
NON_INTERACTIVE=false
VERBOSE=false

# Backup path for load mode
BACKUP_PATH=""

# YubiKey PINs (not stored, only used during setup)
USER_PIN=""
ADMIN_PIN=""

################################################################################
# Color Output Functions
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_debug() {
    local message="$1"
    if [[ "${VERBOSE}" == true ]]; then
        echo -e "${MAGENTA}[DEBUG]${NC} ${message}" | tee -a "${LOG_FILE}"
    else
        echo "[DEBUG] ${message}" >> "${LOG_FILE}"
    fi
}

log_step() {
    local message="$1"
    echo -e "${CYAN}[STEP]${NC} ${message}" | tee -a "${LOG_FILE}"
}

################################################################################
# Helper Functions
################################################################################

# Restart GPG agent and scdaemon
restart_gpg_daemons() {
    log_debug "Restarting GPG daemons..."

    # Kill all GPG-related daemons
    gpgconf --kill gpg-agent 2>/dev/null || true
    gpgconf --kill scdaemon 2>/dev/null || true

    # Wait a moment for processes to fully terminate
    sleep 1

    # Restart gpg-agent (it will start scdaemon when needed)
    gpgconf --launch gpg-agent 2>/dev/null || true

    # Wait for daemons to initialize
    sleep 1

    log_debug "GPG daemons restarted"
}

# Display usage information
usage() {
    cat << EOF
YubiKey SSH and GPG Key Management Script v${SCRIPT_VERSION}

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  -m, --mode MODE          Operation mode: 'generate', 'load', or 'backup' (default: interactive)
  -n, --name NAME          Cardholder name (required for generate mode)
  -e, --email EMAIL        Cardholder email (required for generate mode)
  -b, --backup PATH        Backup directory path for load mode
  -k, --key-type TYPE      Key type: 'rsa4096' or 'ed25519' (default: rsa4096)
  -t, --touch POLICY       Touch policy: 'on', 'off', 'fixed', 'cached' (default: on)
  --skip-ssh               Skip SSH configuration
  --skip-git               Skip Git signing setup
  --no-backup              Skip backup creation (not recommended)
  -y, --yes                Non-interactive mode, assume yes to prompts
  -v, --verbose            Verbose output
  -h, --help               Display this help message
  --version                Display version information

Examples:
  # Interactive mode (recommended for first-time users)
  ${SCRIPT_NAME}

  # Generate new keys non-interactively
  ${SCRIPT_NAME} --mode generate --name "John Doe" --email "john@example.com"

  # Load existing keys from backup
  ${SCRIPT_NAME} --mode load --backup /path/to/backup

  # Backup keys from YubiKey
  ${SCRIPT_NAME} --mode backup

EOF
    exit 0
}

# Display version information
version() {
    echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
    exit 0
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."

    local missing_deps=()

    # Required dependencies
    if ! command_exists gpg; then
        missing_deps+=("gpg (GnuPG >= 2.2.0)")
    fi

    if ! command_exists ykman; then
        missing_deps+=("ykman (YubiKey Manager >= 4.0.0)")
    fi

    if ! command_exists ssh-keygen; then
        missing_deps+=("ssh-keygen (OpenSSH >= 8.2)")
    fi

    if ! command_exists pinentry; then
        log_warning "pinentry not found. GPG may have issues with PIN entry."
    fi

    # Optional dependencies
    if ! command_exists git && [[ "${SKIP_GIT}" == false ]]; then
        log_warning "git not found. Git signing setup will be skipped."
        SKIP_GIT=true
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - ${dep}"
        done
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

# Detect YubiKey
detect_yubikey() {
    log_step "Detecting YubiKey..."

    if ! ykman list | grep -q "YubiKey"; then
        log_error "No YubiKey detected. Please insert your YubiKey and try again."
        exit 1
    fi

    local yubikey_info
    yubikey_info=$(ykman list)
    log_success "YubiKey detected: ${yubikey_info}"
}

# Confirm operation with user
confirm_operation() {
    local message="$1"

    if [[ "${NON_INTERACTIVE}" == true ]]; then
        return 0
    fi

    echo -e "${YELLOW}${message}${NC}"
    read -rp "Continue? [y/N]: " response

    if [[ ! "${response}" =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user."
        exit 0
    fi
}

# Secure input for PINs
read_pin() {
    local prompt="$1"
    local pin_var="$2"
    local pin_value=""

    while true; do
        read -rsp "${prompt}: " pin_value
        echo

        if [[ ${#pin_value} -ge 6 && ${#pin_value} -le 8 ]]; then
            eval "${pin_var}='${pin_value}'"
            break
        else
            log_error "PIN must be 6-8 digits. Please try again."
        fi
    done
}

# Validate email format
validate_email() {
    local email="$1"
    if [[ ! "${email}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid email format: ${email}"
        return 1
    fi
    return 0
}

################################################################################
# YubiKey Configuration Functions
################################################################################

# Initialize YubiKey with PINs and touch policies
initialize_yubikey() {
    log_step "Initializing YubiKey..."

    # Get PINs from user
    if [[ -z "${USER_PIN}" ]]; then
        read_pin "Enter User PIN (6-8 digits)" USER_PIN
        local user_pin_confirm=""
        read_pin "Confirm User PIN" user_pin_confirm

        if [[ "${USER_PIN}" != "${user_pin_confirm}" ]]; then
            log_error "User PINs do not match."
            exit 1
        fi
    fi

    if [[ -z "${ADMIN_PIN}" ]]; then
        read_pin "Enter Admin PIN (8 digits)" ADMIN_PIN
        local admin_pin_confirm=""
        read_pin "Confirm Admin PIN" admin_pin_confirm

        if [[ "${ADMIN_PIN}" != "${admin_pin_confirm}" ]]; then
            log_error "Admin PINs do not match."
            exit 1
        fi
    fi

    # Reset OpenPGP applet (if needed)
    confirm_operation "WARNING: This will reset the OpenPGP applet on your YubiKey. All existing keys will be deleted."

    log_info "Resetting OpenPGP applet..."
    ykman openpgp reset -f || {
        log_error "Failed to reset OpenPGP applet."
        exit 1
    }

    # Set PINs
    log_info "Setting User PIN..."
    gpg --command-fd=0 --pinentry-mode=loopback --status-fd=1 --card-edit > /dev/null 2>&1 <<EOF
admin
passwd
1
123456
${USER_PIN}
${USER_PIN}
q
quit
EOF

    if [[ $? -ne 0 ]]; then
        log_warning "Failed to set User PIN automatically. You may need to set it manually."
    fi

    log_info "Setting Admin PIN..."
    gpg --command-fd=0 --pinentry-mode=loopback --status-fd=1 --card-edit > /dev/null 2>&1 <<EOF
admin
passwd
3
12345678
${ADMIN_PIN}
${ADMIN_PIN}
q
quit
EOF

    if [[ $? -ne 0 ]]; then
        log_warning "Failed to set Admin PIN automatically. You may need to set it manually."
    fi

    # Set touch policies
    if [[ "${TOUCH_POLICY}" != "off" ]]; then
        log_info "Setting touch policy to '${TOUCH_POLICY}'..."
        ykman openpgp keys set-touch sig "${TOUCH_POLICY}" -a "${ADMIN_PIN}" -f || log_warning "Failed to set touch policy for signature"
        ykman openpgp keys set-touch enc "${TOUCH_POLICY}" -a "${ADMIN_PIN}" -f || log_warning "Failed to set touch policy for encryption"
        ykman openpgp keys set-touch aut "${TOUCH_POLICY}" -a "${ADMIN_PIN}" -f || log_warning "Failed to set touch policy for authentication"
    fi

    log_success "YubiKey initialized successfully"
}

################################################################################
# GPG Key Management Functions
################################################################################

# Generate new GPG master key and subkeys
generate_gpg_keys() {
    log_step "Generating GPG keys..."

    # Validate inputs
    if [[ -z "${CARDHOLDER_NAME}" || -z "${CARDHOLDER_EMAIL}" ]]; then
        log_error "Cardholder name and email are required for key generation."
        exit 1
    fi

    if ! validate_email "${CARDHOLDER_EMAIL}"; then
        exit 1
    fi

    local user_id="${CARDHOLDER_NAME} <${CARDHOLDER_EMAIL}>"

    # Generate master key and subkeys using quick commands
    if [[ "${KEY_TYPE}" == "rsa4096" ]]; then
        log_info "Generating RSA 4096-bit master key (this may take a while)..."

        # Generate master key with cert capability only
        gpg --batch --passphrase '' --quick-gen-key "${user_id}" rsa4096 cert never 2>&1 | tee -a "${LOG_FILE}"

        # Get the key fingerprint
        local key_fpr
        key_fpr=$(gpg --list-secret-keys --with-colons "${CARDHOLDER_EMAIL}" | grep '^fpr' | head -n1 | cut -d: -f10)

        if [[ -z "${key_fpr}" ]]; then
            log_error "Failed to generate master key."
            exit 1
        fi

        log_info "Master key generated. Fingerprint: ${key_fpr}"

        # Add signing subkey
        log_info "Adding signing subkey..."
        gpg --batch --passphrase '' --quick-add-key "${key_fpr}" rsa4096 sign never 2>&1 | tee -a "${LOG_FILE}"

        # Add encryption subkey
        log_info "Adding encryption subkey..."
        gpg --batch --passphrase '' --quick-add-key "${key_fpr}" rsa4096 encr never 2>&1 | tee -a "${LOG_FILE}"

        # Add authentication subkey
        log_info "Adding authentication subkey..."
        gpg --batch --passphrase '' --quick-add-key "${key_fpr}" rsa4096 auth never 2>&1 | tee -a "${LOG_FILE}"

    elif [[ "${KEY_TYPE}" == "ed25519" ]]; then
        log_info "Generating Ed25519 master key..."

        # Generate master key with cert capability only
        gpg --batch --passphrase '' --quick-gen-key "${user_id}" ed25519 cert never 2>&1 | tee -a "${LOG_FILE}"

        # Get the key fingerprint
        local key_fpr
        key_fpr=$(gpg --list-secret-keys --with-colons "${CARDHOLDER_EMAIL}" | grep '^fpr' | head -n1 | cut -d: -f10)

        if [[ -z "${key_fpr}" ]]; then
            log_error "Failed to generate master key."
            exit 1
        fi

        log_info "Master key generated. Fingerprint: ${key_fpr}"

        # Add signing subkey
        log_info "Adding signing subkey..."
        gpg --batch --passphrase '' --quick-add-key "${key_fpr}" ed25519 sign never 2>&1 | tee -a "${LOG_FILE}"

        # Add encryption subkey (uses cv25519)
        log_info "Adding encryption subkey..."
        gpg --batch --passphrase '' --quick-add-key "${key_fpr}" cv25519 encr never 2>&1 | tee -a "${LOG_FILE}"

        # Add authentication subkey
        log_info "Adding authentication subkey..."
        gpg --batch --passphrase '' --quick-add-key "${key_fpr}" ed25519 auth never 2>&1 | tee -a "${LOG_FILE}"
    else
        log_error "Invalid key type: ${KEY_TYPE}"
        exit 1
    fi

    # Get the key ID
    local key_id
    key_id=$(gpg --list-secret-keys --with-colons "${CARDHOLDER_EMAIL}" | grep '^sec' | cut -d: -f5)

    if [[ -z "${key_id}" ]]; then
        log_error "Failed to generate GPG keys."
        exit 1
    fi

    log_success "GPG keys generated successfully. Key ID: ${key_id}"
    echo "${key_id}" > /tmp/yubikey-key-id.txt
}

# Transfer GPG subkeys to YubiKey
transfer_gpg_keys_to_yubikey() {
    log_step "Transferring GPG subkeys to YubiKey..."

    # Get the key ID
    local key_id
    if [[ -f /tmp/yubikey-key-id.txt ]]; then
        key_id=$(cat /tmp/yubikey-key-id.txt)
    else
        key_id=$(gpg --list-secret-keys --with-colons "${CARDHOLDER_EMAIL}" | grep '^sec' | cut -d: -f5)
    fi

    if [[ -z "${key_id}" ]]; then
        log_error "Could not find GPG key ID."
        exit 1
    fi

    log_info "Transferring subkeys for key ID: ${key_id}"

    # Create a temporary script to automate the keytocard operation
    local transfer_script="/tmp/yubikey-transfer-$$.exp"

    # Check if expect is available
    if ! command_exists expect; then
        log_error "The 'expect' tool is required for automated key transfer but is not installed."
        log_info "Please install expect:"
        log_info "  macOS: brew install expect"
        log_info "  Linux: apt-get install expect / yum install expect"
        exit 1
    fi

    # Create expect script to handle the interactive keytocard operations
    cat > "${transfer_script}" <<EXPECT_EOF
#!/usr/bin/expect -f
set timeout 120
set key_id [lindex \$argv 0]
set admin_pin [lindex \$argv 1]

# Enable logging for debugging
log_user 1
exp_internal 0

# Set TERM to dumb to disable fancy terminal features like bracketed paste
set env(TERM) "dumb"

# Transfer signing subkey (key 1 -> slot 1)
spawn env TERM=dumb gpg --expert --edit-key \$key_id
expect -re "gpg>.*"
send "key 1\r"
expect -re "gpg>.*"
send "keytocard\r"
expect -re "Your selection\\?.*"
send "1\r"
expect {
    -re "(Admin PIN|PIN).*:" {
        send "\$admin_pin\r"
        exp_continue
    }
    -re "Replace existing key\\?" {
        send "y\r"
        exp_continue
    }
    -re "gpg>.*" {
        send "key 1\r"
    }
}
expect -re "gpg>.*"

# Transfer encryption subkey (key 2 -> slot 2)
send "key 2\r"
expect -re "gpg>.*"
send "keytocard\r"
expect -re "Your selection\\?.*"
send "2\r"
expect {
    -re "(Admin PIN|PIN).*:" {
        send "\$admin_pin\r"
        exp_continue
    }
    -re "Replace existing key\\?" {
        send "y\r"
        exp_continue
    }
    -re "gpg>.*" {
        send "key 2\r"
    }
}
expect -re "gpg>.*"

# Transfer authentication subkey (key 3 -> slot 3)
send "key 3\r"
expect -re "gpg>.*"
send "keytocard\r"
expect -re "Your selection\\?.*"
send "3\r"
expect {
    -re "(Admin PIN|PIN).*:" {
        send "\$admin_pin\r"
        exp_continue
    }
    -re "Replace existing key\\?" {
        send "y\r"
        exp_continue
    }
    -re "gpg>.*" {
        # All done, ready to save
    }
}
# Already at gpg> prompt from the expect block above
send "save\r"
expect {
    eof {
        puts "\\nKey transfer completed successfully"
    }
    timeout {
        puts "\\nERROR: Timeout waiting for GPG to finish"
        exit 1
    }
}
EXPECT_EOF

    chmod +x "${transfer_script}"

    # Transfer signing subkey (slot 1)
    log_info "Transferring signing subkey to slot 1..."
    log_warning "You may need to touch your YubiKey to confirm the operation."

    # Run the expect script
    export GPG_TTY=$(tty)
    if "${transfer_script}" "${key_id}" "${ADMIN_PIN}" 2>&1 | tee -a "${LOG_FILE}"; then
        log_success "GPG subkey transfer commands completed."
    else
        log_error "Expect script failed with exit code $?"
        log_error "Check the log file for details: ${LOG_FILE}"
        rm -f "${transfer_script}"
        exit 1
    fi

    # Clean up
    rm -f "${transfer_script}"

    # Restart GPG daemons to clear any stale state
    log_info "Restarting GPG daemons after key transfer..."
    restart_gpg_daemons

    # Note: Verification is done separately by verify_keys_on_yubikey function
}

# Verify that all keys are properly loaded on YubiKey
verify_keys_on_yubikey() {
    log_step "Verifying keys are loaded on YubiKey..."

    # Get card status with retry logic in case of daemon issues
    local card_status
    local retry_count=0
    local max_retries=3

    while [[ ${retry_count} -lt ${max_retries} ]]; do
        card_status=$(gpg --card-status 2>&1)

        # Check if we got a broken pipe or similar error
        if echo "${card_status}" | grep -qi "broken pipe\|no card\|card error"; then
            log_warning "GPG daemon issue detected, restarting daemons (attempt $((retry_count + 1))/${max_retries})..."
            restart_gpg_daemons
            retry_count=$((retry_count + 1))
            sleep 2
        else
            # Success - got valid card status
            break
        fi
    done

    if [[ ${retry_count} -ge ${max_retries} ]]; then
        log_error "Failed to communicate with YubiKey after ${max_retries} attempts"
        return 1
    fi

    local sig_key_status
    local enc_key_status
    local aut_key_status
    local verification_failed=false

    # Check signature key
    sig_key_status=$(echo "${card_status}" | grep "Signature key")
    if echo "${sig_key_status}" | grep -qv "\[none\]" && [[ -n "${sig_key_status}" ]]; then
        log_success "✓ Signing key on card"
    else
        log_error "✗ Signing key NOT on card"
        verification_failed=true
    fi

    # Check encryption key
    enc_key_status=$(echo "${card_status}" | grep "Encryption key")
    if echo "${enc_key_status}" | grep -qv "\[none\]" && [[ -n "${enc_key_status}" ]]; then
        log_success "✓ Encryption key on card"
    else
        log_error "✗ Encryption key NOT on card"
        verification_failed=true
    fi

    # Check authentication key
    aut_key_status=$(echo "${card_status}" | grep "Authentication key")
    if echo "${aut_key_status}" | grep -qv "\[none\]" && [[ -n "${aut_key_status}" ]]; then
        log_success "✓ Authentication key on card"
    else
        log_error "✗ Authentication key NOT on card"
        verification_failed=true
    fi

    if [[ "${verification_failed}" == true ]]; then
        log_error "Key transfer verification FAILED!"
        echo
        log_error "Detailed Error Report:"
        log_error "====================="
        echo
        log_info "Full card status:"
        echo "${card_status}" | tee -a "${LOG_FILE}"
        echo
        log_info "Checking for key files on disk (should be stubs, not full keys):"

        # Get the key ID
        local key_id
        if [[ -f /tmp/yubikey-key-id.txt ]]; then
            key_id=$(cat /tmp/yubikey-key-id.txt)
        fi

        if [[ -n "${key_id}" ]]; then
            log_info "Key ID: ${key_id}"

            # Check if keys are still on disk (they should be stubs if transfer succeeded)
            local keygrips
            keygrips=$(gpg --list-secret-keys --with-keygrip "${key_id}" 2>/dev/null | grep "Keygrip" | awk '{print $3}')

            if [[ -n "${keygrips}" ]]; then
                log_info "Checking key files in ~/.gnupg/private-keys-v1.d/:"
                for grip in ${keygrips}; do
                    if [[ -f "${HOME}/.gnupg/private-keys-v1.d/${grip}.key" ]]; then
                        local file_size
                        file_size=$(wc -c < "${HOME}/.gnupg/private-keys-v1.d/${grip}.key")
                        if [[ ${file_size} -gt 500 ]]; then
                            log_error "  ${grip}.key: ${file_size} bytes (FULL KEY - transfer failed)"
                        else
                            log_info "  ${grip}.key: ${file_size} bytes (stub - OK)"
                        fi
                    fi
                done
            fi
        fi

        echo
        log_error "Possible causes:"
        log_error "  1. YubiKey touch policy requires physical touch (try touching the key)"
        log_error "  2. Admin PIN was incorrect or not accepted"
        log_error "  3. YubiKey is locked or has PIN retry counter at 0"
        log_error "  4. Expect script timed out or encountered unexpected prompts"
        log_error "  5. GPG version incompatibility"
        echo
        log_info "Troubleshooting steps:"
        log_info "  1. Check YubiKey PIN retry counter: gpg --card-status | grep 'PIN retry counter'"
        log_info "  2. Verify YubiKey is properly connected: ykman list"
        log_info "  3. Try the transfer manually: gpg --expert --edit-key ${key_id}"
        log_info "  4. Check the log file for details: ${LOG_FILE}"
        echo
        log_error "Aborting backup creation - keys are not securely on YubiKey!"

        return 1
    fi

    log_success "All keys verified successfully on YubiKey!"
    return 0
}

# Import existing GPG keys from backup
import_gpg_keys() {
    log_step "Importing GPG keys from backup..."

    if [[ -z "${BACKUP_PATH}" ]]; then
        log_error "Backup path is required for load mode."
        exit 1
    fi

    if [[ ! -d "${BACKUP_PATH}" && ! -f "${BACKUP_PATH}" ]]; then
        log_error "Backup path does not exist: ${BACKUP_PATH}"
        exit 1
    fi

    # Find GPG key files
    local master_key_file=""
    local public_key_file=""

    if [[ -d "${BACKUP_PATH}" ]]; then
        master_key_file="${BACKUP_PATH}/gpg-master-key.asc"
        public_key_file="${BACKUP_PATH}/gpg-public-key.asc"
    elif [[ -f "${BACKUP_PATH}" ]]; then
        # Single file backup
        master_key_file="${BACKUP_PATH}"
    fi

    # Import master key
    if [[ -f "${master_key_file}" ]]; then
        log_info "Importing master key from: ${master_key_file}"
        gpg --import "${master_key_file}" 2>&1 | tee -a "${LOG_FILE}"
    else
        log_error "Master key file not found: ${master_key_file}"
        exit 1
    fi

    # Import public key if available
    if [[ -f "${public_key_file}" ]]; then
        log_info "Importing public key from: ${public_key_file}"
        gpg --import "${public_key_file}" 2>&1 | tee -a "${LOG_FILE}"
    fi

    # List imported keys
    log_info "Available keys:"
    gpg --list-secret-keys

    # Get key ID from imported keys
    local key_id
    key_id=$(gpg --list-secret-keys --with-colons | grep '^sec' | head -n1 | cut -d: -f5)

    if [[ -z "${key_id}" ]]; then
        log_error "No secret keys found after import."
        exit 1
    fi

    log_success "GPG keys imported successfully. Key ID: ${key_id}"
    echo "${key_id}" > /tmp/yubikey-key-id.txt
}

################################################################################
# SSH Configuration Functions
################################################################################

# Generate FIDO2 SSH keys
generate_ssh_keys() {
    log_step "Generating FIDO2 SSH keys..."

    if [[ "${SKIP_SSH}" == true ]]; then
        log_info "SSH configuration skipped."
        return
    fi

    local ssh_key_path="${HOME}/.ssh/id_ecdsa_sk"

    log_info "Generating FIDO2 resident key..."
    log_warning "You will need to touch your YubiKey when prompted."

    ssh-keygen -t ecdsa-sk -O resident -O verify-required -f "${ssh_key_path}" -C "${CARDHOLDER_EMAIL}" || {
        log_error "Failed to generate FIDO2 SSH key."
        exit 1
    }

    log_success "FIDO2 SSH key generated: ${ssh_key_path}.pub"

    # Display public key
    log_info "SSH Public Key:"
    cat "${ssh_key_path}.pub"
}

# Configure GPG agent for SSH authentication
configure_gpg_ssh() {
    log_step "Configuring GPG agent for SSH authentication..."

    if [[ "${SKIP_SSH}" == true ]]; then
        log_info "SSH configuration skipped."
        return
    fi

    # Configure GPG agent
    local gpg_agent_conf="${HOME}/.gnupg/gpg-agent.conf"

    log_info "Configuring GPG agent for SSH support..."

    if ! grep -q "enable-ssh-support" "${gpg_agent_conf}" 2>/dev/null; then
        echo "enable-ssh-support" >> "${gpg_agent_conf}"
    fi

    # Restart GPG agent
    log_info "Restarting GPG agent..."
    gpgconf --kill gpg-agent
    gpg-agent --daemon --enable-ssh-support >/dev/null 2>&1

    # Configure shell RC files
    local shell_rc=""
    if [[ -f "${HOME}/.bashrc" ]]; then
        shell_rc="${HOME}/.bashrc"
    elif [[ -f "${HOME}/.zshrc" ]]; then
        shell_rc="${HOME}/.zshrc"
    fi

    if [[ -n "${shell_rc}" ]]; then
        log_info "Configuring shell RC file: ${shell_rc}"

        if ! grep -q "GPG_TTY" "${shell_rc}" 2>/dev/null; then
            cat >> "${shell_rc}" <<'EOF'

# YubiKey GPG SSH Configuration
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
EOF
        fi
    fi

    # Export authentication subkey for SSH
    local key_id
    if [[ -f /tmp/yubikey-key-id.txt ]]; then
        key_id=$(cat /tmp/yubikey-key-id.txt)
    fi

    if [[ -n "${key_id}" ]]; then
        log_info "Exporting SSH public key from GPG authentication subkey..."
        gpg --export-ssh-key "${key_id}" > "${HOME}/.ssh/id_gpg_yubikey.pub" 2>/dev/null || true

        if [[ -f "${HOME}/.ssh/id_gpg_yubikey.pub" ]]; then
            log_success "GPG SSH public key exported: ${HOME}/.ssh/id_gpg_yubikey.pub"
            log_info "SSH Public Key (GPG):"
            cat "${HOME}/.ssh/id_gpg_yubikey.pub"
        fi
    fi

    log_success "GPG agent configured for SSH authentication"
}

################################################################################
# Git Configuration Functions
################################################################################

# Configure Git for commit signing
configure_git_signing() {
    log_step "Configuring Git commit signing..."

    if [[ "${SKIP_GIT}" == true ]]; then
        log_info "Git configuration skipped."
        return
    fi

    # Get key ID
    local key_id
    if [[ -f /tmp/yubikey-key-id.txt ]]; then
        key_id=$(cat /tmp/yubikey-key-id.txt)
    else
        log_error "Could not find GPG key ID for Git configuration."
        return
    fi

    log_info "Configuring Git to use GPG key: ${key_id}"

    # Set Git configuration
    git config --global user.signingkey "${key_id}"
    git config --global commit.gpgsign true
    git config --global tag.gpgsign true
    git config --global gpg.program "$(command -v gpg)"

    # Set user name and email if provided
    if [[ -n "${CARDHOLDER_NAME}" ]]; then
        git config --global user.name "${CARDHOLDER_NAME}"
    fi

    if [[ -n "${CARDHOLDER_EMAIL}" ]]; then
        git config --global user.email "${CARDHOLDER_EMAIL}"
    fi

    log_success "Git configured for automatic commit signing"
}

################################################################################
# Backup Functions
################################################################################

# Create comprehensive backup
create_backup() {
    log_step "Creating backup..."

    if [[ "${NO_BACKUP}" == true ]]; then
        log_info "Backup creation skipped."
        return
    fi

    # Create backup directory
    local backup_dir="${BACKUP_BASE_DIR}/yubikey-backup-$(date +%Y-%m-%d-%H%M%S)"
    mkdir -p "${backup_dir}"

    log_info "Backup directory: ${backup_dir}"

    # Get key ID
    local key_id
    if [[ -f /tmp/yubikey-key-id.txt ]]; then
        key_id=$(cat /tmp/yubikey-key-id.txt)
    else
        key_id=$(gpg --list-secret-keys --with-colons | grep '^sec' | head -n1 | cut -d: -f5)
    fi

    if [[ -n "${key_id}" ]]; then
        # Export master key
        log_info "Exporting master key..."
        gpg --export-secret-keys --armor "${key_id}" > "${backup_dir}/gpg-master-key.asc"

        # Export public key
        log_info "Exporting public key..."
        gpg --export --armor "${key_id}" > "${backup_dir}/gpg-public-key.asc"

        # Export subkeys
        log_info "Exporting subkeys..."
        gpg --export-secret-subkeys --armor "${key_id}" > "${backup_dir}/gpg-subkeys.asc"
    fi

    # Copy SSH keys
    if [[ -f "${HOME}/.ssh/id_ecdsa_sk.pub" ]]; then
        cp "${HOME}/.ssh/id_ecdsa_sk.pub" "${backup_dir}/ssh-fido2-public.pub"
    fi

    if [[ -f "${HOME}/.ssh/id_gpg_yubikey.pub" ]]; then
        cp "${HOME}/.ssh/id_gpg_yubikey.pub" "${backup_dir}/ssh-gpg-public.pub"
    fi

    # Export YubiKey status
    log_info "Exporting YubiKey status..."
    ykman info > "${backup_dir}/yubikey-status.txt" 2>&1 || true
    gpg --card-status >> "${backup_dir}/yubikey-status.txt" 2>&1 || true

    # Create README
    cat > "${backup_dir}/README.txt" <<EOF
YubiKey Backup - $(date)
========================

This directory contains a backup of your YubiKey configuration and keys.

Contents:
- gpg-master-key.asc: GPG master private key (keep secure!)
- gpg-public-key.asc: GPG public key (safe to share)
- gpg-subkeys.asc: GPG subkeys backup
- ssh-fido2-public.pub: FIDO2 SSH public key
- ssh-gpg-public.pub: GPG authentication public key for SSH
- yubikey-status.txt: YubiKey configuration snapshot
- restore-instructions.txt: Detailed restoration guide

IMPORTANT SECURITY NOTES:
- Store this backup in a secure, encrypted location
- Never share the master private key
- Consider encrypting this entire directory
- Test restoration procedure periodically

Key ID: ${key_id}
Cardholder: ${CARDHOLDER_NAME} <${CARDHOLDER_EMAIL}>
EOF

    # Create restore instructions
    cat > "${backup_dir}/restore-instructions.txt" <<EOF
YubiKey Restoration Instructions
=================================

To restore keys to a new YubiKey:

1. Run the setup script in load mode:
   ${SCRIPT_NAME} --mode load --backup "${backup_dir}"

2. Or manually restore:

   a. Import master key:
      gpg --import gpg-master-key.asc

   b. Import public key:
      gpg --import gpg-public-key.asc

   c. Initialize YubiKey and transfer subkeys:
      ${SCRIPT_NAME} --mode load --backup "${backup_dir}"

3. Verify functionality:
   - Test GPG signing: echo "test" | gpg --clearsign
   - Test SSH: ssh-add -L
   - Test Git signing: git commit --allow-empty -m "test" -S

For detailed help, see the README.md in the scripts directory.
EOF

    log_success "Backup created successfully: ${backup_dir}"
    log_warning "IMPORTANT: Store this backup in a secure, encrypted location!"
}

################################################################################
# Verification Functions
################################################################################

# Verify YubiKey functionality
verify_yubikey() {
    log_step "Verifying YubiKey functionality..."

    # Check YubiKey status
    log_info "YubiKey status:"
    ykman info 2>&1 | tee -a "${LOG_FILE}"

    # Check GPG card status with retry logic
    log_info "GPG card status:"
    local retry_count=0
    local max_retries=2
    local card_check_success=false

    while [[ ${retry_count} -lt ${max_retries} ]]; do
        local card_output
        card_output=$(gpg --card-status 2>&1)

        if echo "${card_output}" | grep -qi "broken pipe\|no card\|card error"; then
            log_warning "GPG daemon issue detected, restarting daemons..."
            restart_gpg_daemons
            retry_count=$((retry_count + 1))
            sleep 2
        else
            echo "${card_output}" | tee -a "${LOG_FILE}"
            card_check_success=true
            break
        fi
    done

    if [[ "${card_check_success}" != true ]]; then
        log_warning "Unable to verify GPG card status, but keys may still be functional"
    fi

    # Test GPG signing
    log_info "Testing GPG signing..."
    echo "test" | gpg --clearsign >/dev/null 2>&1 && log_success "GPG signing works" || log_warning "GPG signing test failed"

    # Test SSH
    if [[ "${SKIP_SSH}" == false ]]; then
        log_info "Testing SSH key listing..."
        ssh-add -L 2>&1 | tee -a "${LOG_FILE}" || log_warning "SSH key listing failed"
    fi

    log_success "Verification complete"
}

################################################################################
# Main Workflow Functions
################################################################################

# Mode 1: Generate new keys
mode_generate() {
    log_info "Starting Generate New Keys mode..."

    # Collect information if not provided
    if [[ -z "${CARDHOLDER_NAME}" ]]; then
        read -rp "Enter your full name: " CARDHOLDER_NAME
    fi

    if [[ -z "${CARDHOLDER_EMAIL}" ]]; then
        read -rp "Enter your email address: " CARDHOLDER_EMAIL
    fi

    # Display configuration
    echo
    log_info "Configuration:"
    echo "  Name: ${CARDHOLDER_NAME}"
    echo "  Email: ${CARDHOLDER_EMAIL}"
    echo "  Key Type: ${KEY_TYPE}"
    echo "  Touch Policy: ${TOUCH_POLICY}"
    echo

    confirm_operation "WARNING: This will generate NEW keys and transfer them to your YubiKey. Existing keys on the YubiKey will be OVERWRITTEN."

    # Execute workflow
    detect_yubikey
    initialize_yubikey
    generate_gpg_keys
    transfer_gpg_keys_to_yubikey

    # Verify keys are on YubiKey before proceeding
    if ! verify_keys_on_yubikey; then
        log_error "YubiKey setup FAILED - keys were not successfully transferred to YubiKey."
        log_error "No backup was created for security reasons."
        exit 1
    fi

    if [[ "${SKIP_SSH}" == false ]]; then
        generate_ssh_keys
        configure_gpg_ssh
    fi

    if [[ "${SKIP_GIT}" == false ]]; then
        configure_git_signing
    fi

    create_backup
    verify_yubikey

    log_success "YubiKey setup complete!"
    echo
    log_info "Next steps:"
    echo "  1. Add your SSH public key to servers/GitHub/GitLab"
    echo "  2. Add your GPG public key to GitHub/GitLab for verified commits"
    echo "  3. Test SSH authentication and Git commit signing"
    echo "  4. Store your backup securely: ${BACKUP_BASE_DIR}"
}

# Mode 2: Load existing keys
mode_load() {
    log_info "Starting Load Existing Keys mode..."

    # Get backup path if not provided
    if [[ -z "${BACKUP_PATH}" ]]; then
        read -rp "Enter backup directory or file path: " BACKUP_PATH
    fi

    if [[ ! -e "${BACKUP_PATH}" ]]; then
        log_error "Backup path does not exist: ${BACKUP_PATH}"
        exit 1
    fi

    confirm_operation "WARNING: This will MOVE subkeys to your YubiKey. Ensure you have secure backups."

    # Execute workflow
    detect_yubikey
    initialize_yubikey
    import_gpg_keys
    transfer_gpg_keys_to_yubikey

    # Verify keys are on YubiKey before proceeding
    if ! verify_keys_on_yubikey; then
        log_error "YubiKey load FAILED - keys were not successfully transferred to YubiKey."
        exit 1
    fi

    if [[ "${SKIP_SSH}" == false ]]; then
        configure_gpg_ssh
    fi

    if [[ "${SKIP_GIT}" == false ]]; then
        configure_git_signing
    fi

    verify_yubikey

    log_success "YubiKey loaded with existing keys successfully!"
    echo
    log_info "Next steps:"
    echo "  1. Verify SSH authentication works"
    echo "  2. Verify Git commit signing works"
    echo "  3. Test YubiKey functionality"
}

# Mode 3: Backup existing YubiKey
mode_backup() {
    log_info "Starting Backup YubiKey mode..."

    # Detect YubiKey
    detect_yubikey

    # Check if keys exist on the card
    log_step "Checking for keys on YubiKey..."

    local card_status
    card_status=$(gpg --card-status 2>&1)

    # Check if any keys are present
    if ! echo "${card_status}" | grep -qE "(Signature key|Encryption key|Authentication key)" || \
       echo "${card_status}" | grep -q "\[none\]"; then
        log_error "No keys found on YubiKey card. Cannot create backup."
        log_info "Card status:"
        echo "${card_status}"
        exit 1
    fi

    log_success "Keys detected on YubiKey"

    # Try to extract cardholder information from card
    local card_name
    local card_email
    card_name=$(echo "${card_status}" | grep "Name of cardholder:" | cut -d: -f2- | xargs)

    # Extract key ID from card
    local key_id
    key_id=$(echo "${card_status}" | grep -E "^General key info" -A1 | grep -oE "[A-F0-9]{16}" | head -n1)

    if [[ -z "${key_id}" ]]; then
        # Try alternative method to get key ID
        key_id=$(gpg --card-status 2>&1 | grep -oE "sec[>#].*\/[A-F0-9]{16}" | grep -oE "[A-F0-9]{16}")
    fi

    if [[ -n "${key_id}" ]]; then
        log_info "Found GPG key ID on card: ${key_id}"
        echo "${key_id}" > /tmp/yubikey-key-id.txt

        # Try to get email from GPG key
        if gpg --list-keys "${key_id}" >/dev/null 2>&1; then
            card_email=$(gpg --list-keys "${key_id}" 2>/dev/null | grep -oE "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b" | head -n1)
            if [[ -z "${CARDHOLDER_EMAIL}" && -n "${card_email}" ]]; then
                CARDHOLDER_EMAIL="${card_email}"
            fi
        fi
    else
        log_warning "Could not determine key ID from YubiKey"
    fi

    # Display information
    echo
    log_info "YubiKey Information:"
    if [[ -n "${card_name}" ]]; then
        echo "  Cardholder: ${card_name}"
    fi
    if [[ -n "${card_email}" ]]; then
        echo "  Email: ${card_email}"
    fi
    if [[ -n "${key_id}" ]]; then
        echo "  Key ID: ${key_id}"
    fi
    echo

    # Show current card status
    log_info "Current YubiKey Card Status:"
    echo "${card_status}" | grep -E "(Application|Version|Serial|Signature key|Encryption key|Authentication key|Name of cardholder)" | tee -a "${LOG_FILE}"
    echo

    confirm_operation "This will create a backup of the public keys and card information from your YubiKey."

    # Create backup
    create_backup

    log_success "YubiKey backup completed successfully!"
    echo
    log_info "Backup location: ${BACKUP_BASE_DIR}"
    log_warning "Note: Private keys cannot be exported from YubiKey hardware."
    log_warning "This backup contains only public keys and card configuration."
    echo
    log_info "What was backed up:"
    echo "  ✓ GPG public key"
    echo "  ✓ GPG subkeys (stub references)"
    echo "  ✓ SSH public keys (if available)"
    echo "  ✓ YubiKey configuration and status"
    echo
    log_info "What was NOT backed up (hardware-protected):"
    echo "  ✗ Private keys (stored securely on YubiKey chip)"
    echo "  ✗ PINs (never exported)"
}

# Interactive mode selection
interactive_mode() {
    echo
    echo "========================================"
    echo "  Welcome to YubiKey Setup Script"
    echo "========================================"
    echo
    echo "This script will help you configure your YubiKey 5 NFC for SSH and GPG."
    echo
    echo "Select operation mode:"
    echo "  1) Generate new keys (first-time setup)"
    echo "  2) Load existing keys (backup/secondary YubiKey)"
    echo "  3) Backup existing YubiKey (export public keys and config)"
    echo

    local selection=""
    read -rp "Enter selection [1-3]: " selection

    case "${selection}" in
        1)
            MODE="generate"
            ;;
        2)
            MODE="load"
            ;;
        3)
            MODE="backup"
            ;;
        *)
            log_error "Invalid selection: ${selection}"
            exit 1
            ;;
    esac
}

################################################################################
# Argument Parsing
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -n|--name)
                CARDHOLDER_NAME="$2"
                shift 2
                ;;
            -e|--email)
                CARDHOLDER_EMAIL="$2"
                shift 2
                ;;
            -b|--backup)
                BACKUP_PATH="$2"
                shift 2
                ;;
            -k|--key-type)
                KEY_TYPE="$2"
                shift 2
                ;;
            -t|--touch)
                TOUCH_POLICY="$2"
                shift 2
                ;;
            --skip-ssh)
                SKIP_SSH=true
                shift
                ;;
            --skip-git)
                SKIP_GIT=true
                shift
                ;;
            --no-backup)
                NO_BACKUP=true
                shift
                ;;
            -y|--yes)
                NON_INTERACTIVE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            --version)
                version
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

################################################################################
# Main Function
################################################################################

main() {
    # Parse command-line arguments
    parse_arguments "$@"

    # Display banner
    echo "YubiKey Setup Script v${SCRIPT_VERSION}"
    echo "Log file: ${LOG_FILE}"
    echo

    # Check prerequisites
    check_prerequisites

    # Select mode if not specified
    if [[ -z "${MODE}" ]]; then
        interactive_mode
    fi

    # Validate mode
    if [[ "${MODE}" != "generate" && "${MODE}" != "load" && "${MODE}" != "backup" ]]; then
        log_error "Invalid mode: ${MODE}. Must be 'generate', 'load', or 'backup'."
        exit 1
    fi

    # Execute selected mode
    case "${MODE}" in
        generate)
            mode_generate
            ;;
        load)
            mode_load
            ;;
        backup)
            mode_backup
            ;;
    esac

    # Cleanup
    rm -f /tmp/yubikey-key-id.txt

    echo
    log_success "All operations completed successfully!"
    log_info "Log file saved to: ${LOG_FILE}"
}

################################################################################
# Script Entry Point
################################################################################

# Trap errors
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"
