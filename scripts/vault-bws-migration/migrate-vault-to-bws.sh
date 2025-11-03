#!/usr/bin/env bash
#
# migrate-vault-to-bws.sh
#
# Migrates Ansible Vault secrets to Bitwarden Secrets Manager
#
# Usage: ./migrate-vault-to-bws.sh [OPTIONS]
#
# Author: Home Lab Infrastructure Team
# Version: 1.0.0
# License: MIT

set -euo pipefail

# Script constants
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REQUIRED_ANSIBLE_VERSION="2.19.0"
readonly REQUIRED_BWS_VERSION="1.0.0"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Default values
ANSIBLE_DIR="/etc/ansible"
DRY_RUN=false
VERBOSE=false
ENVIRONMENT=""
PROJECT_ID=""
VAULT_PASSWORD_FILE=""
ASK_VAULT_PASSWORD=false
OUTPUT_DIR="${SCRIPT_DIR}/migration-output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Statistics
TOTAL_FILES=0
TOTAL_SECRETS=0
TOTAL_CREATED=0
TOTAL_ERRORS=0

#######################################
# Print colored message
# Arguments:
#   $1 - Color code
#   $2 - Message
#######################################
print_color() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

#######################################
# Print info message
#######################################
info() {
    print_color "${BLUE}" "ℹ [INFO] $*"
}

#######################################
# Print success message
#######################################
success() {
    print_color "${GREEN}" "✓ [SUCCESS] $*"
}

#######################################
# Print warning message
#######################################
warn() {
    print_color "${YELLOW}" "⚠ [WARNING] $*"
}

#######################################
# Print error message
#######################################
error() {
    print_color "${RED}" "✗ [ERROR] $*" >&2
}

#######################################
# Print debug message (verbose mode)
#######################################
debug() {
    if [[ "${VERBOSE}" == true ]]; then
        print_color "${CYAN}" "🔍 [DEBUG] $*"
    fi
}

#######################################
# Print usage information
#######################################
usage() {
    cat << EOF
${BOLD}Ansible Vault to Bitwarden Secrets Manager Migration Tool${NC}
Version: ${SCRIPT_VERSION}

${BOLD}USAGE:${NC}
    ${SCRIPT_NAME} [OPTIONS]

${BOLD}DESCRIPTION:${NC}
    Scans Ansible directory for vault-encrypted files, extracts secrets,
    and migrates them to Bitwarden Secrets Manager.

${BOLD}OPTIONS:${NC}
    --ansible-dir PATH      Path to ansible directory (default: /etc/ansible)
    --project-id ID         Bitwarden project ID for organizing secrets
    --environment ENV       Environment tag (prod/staging/dev)
    --dry-run              Preview migration without creating secrets
    --verbose              Enable verbose output
    -h, --help             Display this help message
    -v, --version          Display script version

${BOLD}EXAMPLES:${NC}
    # Basic migration with default ansible directory
    ${SCRIPT_NAME}

    # Migrate from custom ansible directory
    ${SCRIPT_NAME} --ansible-dir ~/ansible

    # Dry run to preview secrets
    ${SCRIPT_NAME} --ansible-dir ~/ansible --dry-run

    # Migrate with project ID and environment tag
    ${SCRIPT_NAME} --project-id abc123 --environment prod --verbose

${BOLD}PREREQUISITES:${NC}
    1. ansible-vault command installed (ansible-core >= ${REQUIRED_ANSIBLE_VERSION})
    2. bws command installed (>= ${REQUIRED_BWS_VERSION})
    3. .vault_password file in ansible directory OR use --ask-vault-password
    4. BWS_ACCESS_TOKEN environment variable set

${BOLD}AUTHENTICATION:${NC}
    Set BWS_ACCESS_TOKEN before running:

    # For bash
    export BWS_ACCESS_TOKEN="your-machine-account-token"
    echo 'export BWS_ACCESS_TOKEN="your-token"' >> ~/.bashrc

    # For zsh
    export BWS_ACCESS_TOKEN="your-machine-account-token"
    echo 'export BWS_ACCESS_TOKEN="your-token"' >> ~/.zshrc

${BOLD}OUTPUT:${NC}
    Migration results saved to: ${OUTPUT_DIR}/
    - migration-report-TIMESTAMP.txt  : Summary report
    - secret-mapping-TIMESTAMP.csv    : Vault to BWS mapping
    - errors-TIMESTAMP.log            : Error log (if any)

EOF
}

#######################################
# Print version information
#######################################
version() {
    echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
}

#######################################
# Compare version strings
# Returns:
#   0 if version1 >= version2
#   1 if version1 < version2
#######################################
version_gte() {
    local version1="$1"
    local version2="$2"

    # Remove any non-numeric prefixes (like 'v')
    version1="${version1#v}"
    version2="${version2#v}"

    # Use sort -V for version comparison
    printf '%s\n%s\n' "$version2" "$version1" | sort -V -C
}

#######################################
# Detect operating system
# Returns:
#   "macos" or "linux"
#######################################
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

#######################################
# Check if command exists
#######################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#######################################
# Install or update ansible-core
#######################################
install_ansible() {
    local os
    os=$(detect_os)

    info "Installing/updating ansible-core..."

    if command_exists pip3; then
        pip3 install --upgrade "ansible-core>=${REQUIRED_ANSIBLE_VERSION}" || {
            error "Failed to install ansible-core via pip3"
            return 1
        }
    elif command_exists pip; then
        pip install --upgrade "ansible-core>=${REQUIRED_ANSIBLE_VERSION}" || {
            error "Failed to install ansible-core via pip"
            return 1
        }
    else
        error "pip/pip3 not found. Please install Python and pip first."
        return 1
    fi

    success "ansible-core installed successfully"
}

#######################################
# Install or update bws (Bitwarden Secrets CLI)
#######################################
install_bws() {
    local os
    os=$(detect_os)

    info "Installing/updating bws (Bitwarden Secrets CLI)..."

    # Try cargo first (preferred method)
    if command_exists cargo; then
        info "Installing bws via cargo..."
        cargo install bws || {
            error "Failed to install bws via cargo"
            return 1
        }
        success "bws installed via cargo"
        return 0
    fi

    # Try brew on macOS
    if [[ "$os" == "macos" ]] && command_exists brew; then
        info "Installing bws via Homebrew..."
        brew install bitwarden/tap/bws || {
            error "Failed to install bws via brew"
            return 1
        }
        success "bws installed via Homebrew"
        return 0
    fi

    # Direct binary download as fallback
    info "Downloading bws binary directly..."
    local arch
    local download_url

    arch=$(uname -m)
    case "$arch" in
        x86_64)
            arch="x86_64"
            ;;
        arm64|aarch64)
            arch="aarch64"
            ;;
        *)
            error "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    if [[ "$os" == "macos" ]]; then
        download_url="https://github.com/bitwarden/sdk/releases/latest/download/bws-${arch}-apple-darwin"
    elif [[ "$os" == "linux" ]]; then
        download_url="https://github.com/bitwarden/sdk/releases/latest/download/bws-${arch}-unknown-linux-gnu"
    else
        error "Unsupported OS for binary download: $os"
        return 1
    fi

    local install_dir="${HOME}/.local/bin"
    mkdir -p "$install_dir"

    if command_exists curl; then
        curl -L -o "${install_dir}/bws" "$download_url" || {
            error "Failed to download bws"
            return 1
        }
    elif command_exists wget; then
        wget -O "${install_dir}/bws" "$download_url" || {
            error "Failed to download bws"
            return 1
        }
    else
        error "Neither curl nor wget found. Cannot download bws."
        return 1
    fi

    chmod +x "${install_dir}/bws"

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
        warn "Please add ${install_dir} to your PATH:"
        echo "  export PATH=\"\${PATH}:${install_dir}\""
    fi

    success "bws installed to ${install_dir}/bws"
}

#######################################
# Check dependencies
#######################################
check_dependencies() {
    info "Checking dependencies..."

    local deps_ok=true

    # Check ansible-vault
    if ! command_exists ansible-vault; then
        warn "ansible-vault not found"
        read -rp "Install ansible-core now? [y/N]: " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            install_ansible || deps_ok=false
        else
            error "ansible-vault is required"
            deps_ok=false
        fi
    else
        local ansible_version
        ansible_version=$(ansible --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
        debug "Found ansible version: $ansible_version"

        if ! version_gte "$ansible_version" "$REQUIRED_ANSIBLE_VERSION"; then
            warn "ansible-core version $ansible_version is older than required $REQUIRED_ANSIBLE_VERSION"
            read -rp "Update ansible-core now? [y/N]: " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                install_ansible || deps_ok=false
            else
                warn "Proceeding with older ansible-core version (may cause issues)"
            fi
        else
            success "ansible-vault found (version: $ansible_version)"
        fi
    fi

    # Check bws
    if ! command_exists bws; then
        warn "bws (Bitwarden Secrets CLI) not found"
        read -rp "Install bws now? [y/N]: " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            install_bws || deps_ok=false
        else
            error "bws is required"
            deps_ok=false
        fi
    else
        local bws_version
        bws_version=$(bws --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
        debug "Found bws version: $bws_version"

        if ! version_gte "$bws_version" "$REQUIRED_BWS_VERSION"; then
            warn "bws version $bws_version is older than required $REQUIRED_BWS_VERSION"
            read -rp "Update bws now? [y/N]: " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                install_bws || deps_ok=false
            else
                warn "Proceeding with older bws version (may cause issues)"
            fi
        else
            success "bws found (version: $bws_version)"
        fi
    fi

    # Check Python (for YAML parsing)
    if ! command_exists python3; then
        error "python3 is required for YAML parsing"
        deps_ok=false
    else
        success "python3 found"
    fi

    if [[ "$deps_ok" != true ]]; then
        error "Dependency check failed. Please install missing dependencies."
        exit 1
    fi

    success "All dependencies satisfied"
}

#######################################
# Check authentication
#######################################
check_authentication() {
    info "Checking authentication..."

    # Check for vault password
    if [[ -z "$VAULT_PASSWORD_FILE" ]]; then
        VAULT_PASSWORD_FILE="${ANSIBLE_DIR}/.vault_password"
    fi

    if [[ -f "$VAULT_PASSWORD_FILE" ]]; then
        success "Found vault password file: $VAULT_PASSWORD_FILE"
    else
        warn "Vault password file not found: $VAULT_PASSWORD_FILE"
        ASK_VAULT_PASSWORD=true
        info "Will prompt for vault password when decrypting files"
    fi

    # Check BWS_ACCESS_TOKEN
    if [[ -z "${BWS_ACCESS_TOKEN:-}" ]]; then
        error "BWS_ACCESS_TOKEN environment variable is not set"
        error ""
        error "Please set BWS_ACCESS_TOKEN before running this script:"
        error ""
        error "  For bash:"
        error "    export BWS_ACCESS_TOKEN=\"your-machine-account-token\""
        error "    echo 'export BWS_ACCESS_TOKEN=\"your-token\"' >> ~/.bashrc"
        error ""
        error "  For zsh:"
        error "    export BWS_ACCESS_TOKEN=\"your-machine-account-token\""
        error "    echo 'export BWS_ACCESS_TOKEN=\"your-token\"' >> ~/.zshrc"
        error ""
        error "  Then restart your shell or run: source ~/.bashrc (or ~/.zshrc)"
        exit 1
    fi

    # Test BWS authentication
    debug "Testing Bitwarden authentication..."
    if ! bws secret list >/dev/null 2>&1; then
        error "Failed to authenticate with Bitwarden Secrets Manager"
        error "Please verify your BWS_ACCESS_TOKEN is valid"
        exit 1
    fi

    success "Bitwarden authentication successful"
}

#######################################
# Validate ansible directory
#######################################
validate_ansible_dir() {
    info "Validating ansible directory: $ANSIBLE_DIR"

    if [[ ! -d "$ANSIBLE_DIR" ]]; then
        error "Ansible directory does not exist: $ANSIBLE_DIR"
        exit 1
    fi

    # Check for expected structure
    local has_structure=false
    if [[ -d "${ANSIBLE_DIR}/group_vars" ]] || [[ -d "${ANSIBLE_DIR}/host_vars" ]]; then
        has_structure=true
    fi

    if [[ "$has_structure" != true ]]; then
        warn "Directory does not appear to be an ansible directory (no group_vars or host_vars)"
        read -rp "Continue anyway? [y/N]: " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            error "Aborting migration"
            exit 1
        fi
    fi

    success "Ansible directory validated"
}

#######################################
# Check if file is vault encrypted
#######################################
is_vault_encrypted() {
    local file="$1"
    head -n1 "$file" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT;1\.[0-9];AES256'
}

#######################################
# Find all vault files
#######################################
find_vault_files() {
    # Redirect informational output to stderr so only file paths go to stdout
    info "Scanning for vault files in: $ANSIBLE_DIR" >&2

    local vault_files=()

    # Search in group_vars and host_vars
    while IFS= read -r -d '' file; do
        # Skip template files
        if [[ "$file" =~ \.template$ ]]; then
            debug "Skipping template file: $file" >&2
            continue
        fi

        # Check if encrypted
        if is_vault_encrypted "$file"; then
            vault_files+=("$file")
            debug "Found encrypted vault file: $file" >&2
        else
            debug "Skipping unencrypted file: $file" >&2
        fi
    done < <(find "$ANSIBLE_DIR" -type f \( -name "*vault*.yml" -o -name "*vault*.yaml" \) -print0 2>/dev/null)

    TOTAL_FILES=${#vault_files[@]}

    if [[ $TOTAL_FILES -eq 0 ]]; then
        warn "No encrypted vault files found in $ANSIBLE_DIR" >&2
        exit 0
    fi

    success "Found $TOTAL_FILES encrypted vault files" >&2

    # Return files as array (to stdout only)
    printf '%s\n' "${vault_files[@]}"
}

#######################################
# Decrypt vault file to stdout
#######################################
decrypt_vault_file() {
    local file="$1"

    if [[ "$ASK_VAULT_PASSWORD" == true ]]; then
        ansible-vault view "$file" --ask-vault-password 2>/dev/null
    else
        ansible-vault view "$file" --vault-password-file="$VAULT_PASSWORD_FILE" 2>/dev/null
    fi
}

#######################################
# Parse YAML and extract secrets
#######################################
extract_secrets() {
    local yaml_content="$1"
    local file_path="$2"

    # Use Python to parse YAML and extract all variables from vault files
    # Pass YAML content via stdin to avoid command-line argument length limits
    printf '%s\n' "$yaml_content" | python3 -c '
import sys
import yaml
import json

try:
    # Read YAML content from stdin
    yaml_content = sys.stdin.read()

    data = yaml.safe_load(yaml_content)

    if not isinstance(data, dict):
        print(json.dumps([]))
        sys.exit(0)

    secrets = []

    def extract_vault_vars(obj, prefix=""):
        if isinstance(obj, dict):
            for key, value in obj.items():
                full_key = f"{prefix}{key}" if prefix else key

                # Extract all top-level variables from vault files
                # Skip None values (commented out variables are loaded as None by YAML parser)
                if value is not None and not isinstance(value, dict):
                    secrets.append({
                        "key": full_key,
                        "value": str(value) if not isinstance(value, list) else json.dumps(value),
                        "type": type(value).__name__
                    })
                elif isinstance(value, dict):
                    # Recursively handle nested dictionaries
                    extract_vault_vars(value, f"{full_key}.")

    extract_vault_vars(data)

    # Output as JSON
    print(json.dumps(secrets))

except yaml.YAMLError as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(1)
'
}

#######################################
# Generate Bitwarden secret name
#######################################
generate_secret_name() {
    local vault_var="$1"
    local file_path="$2"

    # Extract service name from file path
    local service
    service=$(basename "$file_path" .yml)
    service="${service//_vault/}"
    service="${service//_/-}"

    # Convert variable name underscores to hyphens
    local var_name="${vault_var//_/-}"

    # Construct secret name: {environment}-{service}-{variable-name}
    local secret_name
    if [[ -n "$ENVIRONMENT" ]]; then
        secret_name="${ENVIRONMENT}-${service}-${var_name}"
    else
        secret_name="prod-${service}-${var_name}"
    fi

    echo "$secret_name"
}

#######################################
# Create secret in Bitwarden
#######################################
create_bws_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local project_id="${3:-}"

    debug "Creating secret: $secret_name"

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would create secret: $secret_name"
        echo "dryrun-secret-id-${RANDOM}"
        return 0
    fi

    # Build bws command
    local cmd="bws secret create \"$secret_name\" \"$secret_value\""

    if [[ -n "$project_id" ]]; then
        cmd="$cmd --project-id \"$project_id\""
    fi

    # Execute and capture secret ID
    local output
    if output=$(eval "$cmd" 2>&1); then
        # Extract secret ID from output (bws returns JSON)
        local secret_id
        secret_id=$(echo "$output" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null || echo "")

        if [[ -n "$secret_id" ]]; then
            debug "Created secret with ID: $secret_id"
            echo "$secret_id"
            return 0
        else
            error "Failed to extract secret ID from bws output"
            return 1
        fi
    else
        error "Failed to create secret: $output"
        return 1
    fi
}

#######################################
# Process a single vault file
#######################################
process_vault_file() {
    local file="$1"
    local mapping_file="$2"

    info "Processing: $(basename "$file")"

    # Decrypt file (only capture stdout, suppress stderr)
    local decrypted_content
    if ! decrypted_content=$(decrypt_vault_file "$file"); then
        error "Failed to decrypt: $file"
        debug "Decryption may have failed due to incorrect vault password"
        ((TOTAL_ERRORS++))
        return 1
    fi

    # Verify we got content
    if [[ -z "$decrypted_content" ]]; then
        error "Decryption returned empty content: $file"
        ((TOTAL_ERRORS++))
        return 1
    fi

    debug "Successfully decrypted $(wc -l <<< "$decrypted_content") lines from $(basename "$file")"

    # Extract secrets (only capture stdout)
    local secrets_json
    if ! secrets_json=$(extract_secrets "$decrypted_content" "$file"); then
        error "Failed to parse YAML from: $file"
        debug "YAML parsing error - check if file contains valid YAML"
        ((TOTAL_ERRORS++))
        return 1
    fi

    # Verify we got valid JSON
    if ! echo "$secrets_json" | python3 -c "import sys, json; json.load(sys.stdin)" >/dev/null 2>&1; then
        error "extract_secrets did not return valid JSON for: $file"
        debug "Got: $secrets_json"
        ((TOTAL_ERRORS++))
        return 1
    fi

    # Check if any secrets found
    local secret_count
    secret_count=$(echo "$secrets_json" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [[ "$secret_count" -eq 0 ]]; then
        warn "No secrets found in: $file"
        return 0
    fi

    info "Found $secret_count secrets in $(basename "$file")"

    # Process each secret
    local index=0
    while [[ $index -lt $secret_count ]]; do
        local secret_data
        secret_data=$(echo "$secrets_json" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin)[$index]))" 2>/dev/null)

        local vault_var
        local secret_value
        vault_var=$(echo "$secret_data" | python3 -c "import sys, json; print(json.load(sys.stdin)['key'])" 2>/dev/null)
        secret_value=$(echo "$secret_data" | python3 -c "import sys, json; print(json.load(sys.stdin)['value'])" 2>/dev/null)

        : $((TOTAL_SECRETS++))

        # Generate Bitwarden secret name
        local secret_name
        secret_name=$(generate_secret_name "$vault_var" "$file")

        # Create secret
        local secret_id
        if secret_id=$(create_bws_secret "$secret_name" "$secret_value" "$PROJECT_ID"); then
            : $((TOTAL_CREATED++))
            success "Created: $secret_name"

            # Log to mapping file
            echo "\"$vault_var\",\"$secret_name\",\"$secret_id\",\"$file\"" >> "$mapping_file"
        else
            error "Failed to create: $secret_name"
            : $((TOTAL_ERRORS++))
        fi

        index=$((index + 1))
    done
}

#######################################
# Main migration logic
#######################################
main() {
    # Print header
    print_color "${BOLD}${MAGENTA}" "╔═══════════════════════════════════════════════════════════════╗"
    print_color "${BOLD}${MAGENTA}" "║  Ansible Vault to Bitwarden Secrets Manager Migration Tool  ║"
    print_color "${BOLD}${MAGENTA}" "║                     Version ${SCRIPT_VERSION}                            ║"
    print_color "${BOLD}${MAGENTA}" "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Output files
    local report_file="${OUTPUT_DIR}/migration-report-${TIMESTAMP}.txt"
    local mapping_file="${OUTPUT_DIR}/secret-mapping-${TIMESTAMP}.csv"
    local error_file="${OUTPUT_DIR}/errors-${TIMESTAMP}.log"

    # Initialize mapping file with header
    echo "\"Vault Variable\",\"BWS Secret Name\",\"BWS Secret ID\",\"Source File\"" > "$mapping_file"

    # Check dependencies
    check_dependencies

    # Validate ansible directory
    validate_ansible_dir

    # Check authentication
    check_authentication

    echo ""
    info "Starting migration..."
    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN MODE - No secrets will be created"
    fi
    echo ""

    # Find vault files
    local vault_files
    mapfile -t vault_files < <(find_vault_files)

    echo ""

    # Process each file
    for file in "${vault_files[@]}"; do
        process_vault_file "$file" "$mapping_file"
        echo ""
    done

    # Generate report
    {
        echo "════════════════════════════════════════════════════════════════"
        echo "Ansible Vault to Bitwarden Secrets Manager Migration Report"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
        echo "Migration Date: $(date)"
        echo "Ansible Directory: $ANSIBLE_DIR"
        echo "Environment: ${ENVIRONMENT:-prod (default)}"
        echo "Project ID: ${PROJECT_ID:-<none>}"
        echo "Dry Run: $DRY_RUN"
        echo ""
        echo "────────────────────────────────────────────────────────────────"
        echo "Statistics"
        echo "────────────────────────────────────────────────────────────────"
        echo "Vault Files Processed: $TOTAL_FILES"
        echo "Secrets Discovered: $TOTAL_SECRETS"
        echo "Secrets Created: $TOTAL_CREATED"
        echo "Errors: $TOTAL_ERRORS"
        echo ""
        echo "────────────────────────────────────────────────────────────────"
        echo "Output Files"
        echo "────────────────────────────────────────────────────────────────"
        echo "Report: $report_file"
        echo "Mapping: $mapping_file"
        if [[ $TOTAL_ERRORS -gt 0 ]]; then
            echo "Errors: $error_file"
        fi
        echo ""
        echo "────────────────────────────────────────────────────────────────"
        echo "Next Steps"
        echo "────────────────────────────────────────────────────────────────"
        echo "1. Review the secret mapping file: $mapping_file"
        echo "2. Update Ansible playbooks to use Bitwarden lookup:"
        echo "   OLD: variable: \"{{ vault_variable_name }}\""
        echo "   NEW: variable: \"{{ lookup('bitwarden.secrets.lookup', 'bws-secret-id') }}\""
        echo "3. Test playbooks in staging environment"
        echo "4. Archive vault files after successful migration"
        echo ""
    } | tee "$report_file"

    # Print summary
    print_color "${BOLD}${GREEN}" "════════════════════════════════════════════════════════════════"
    print_color "${BOLD}${GREEN}" "Migration Summary"
    print_color "${BOLD}${GREEN}" "════════════════════════════════════════════════════════════════"
    echo ""

    if [[ $TOTAL_ERRORS -eq 0 ]]; then
        success "Migration completed successfully!"
    else
        warn "Migration completed with $TOTAL_ERRORS errors"
    fi

    echo ""
    info "Files Processed: $TOTAL_FILES"
    info "Secrets Migrated: $TOTAL_CREATED / $TOTAL_SECRETS"
    echo ""
    info "Results saved to: $OUTPUT_DIR"
    echo ""
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ansible-dir)
                ANSIBLE_DIR="$2"
                shift 2
                ;;
            --project-id)
                PROJECT_ID="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                version
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo ""
                usage
                exit 1
                ;;
        esac
    done
}

# Entry point
parse_args "$@"
main
