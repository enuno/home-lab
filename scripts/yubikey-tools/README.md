# YubiKey SSH and GPG Key Management Script

This document provides detailed documentation for the `yubikey-setup.sh` script, a comprehensive tool for configuring YubiKey 5 NFC devices for SSH authentication and GPG code signing.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Installation](#2-installation)
3. [Quick Start](#3-quick-start)
4. [Detailed Usage](#4-detailed-usage)
5. [Operational Modes](#5-operational-modes)
6. [Configuration Options](#6-configuration-options)
7. [How the Script Functions](#7-how-the-script-functions)
8. [Security Considerations](#8-security-considerations)
9. [Troubleshooting](#9-troubleshooting)
10. [Backup and Recovery](#10-backup-and-recovery)
11. [Contributing](#11-contributing)

---

## 1. Introduction

The `yubikey-setup.sh` script automates the process of setting up a YubiKey 5 NFC for secure SSH and GPG operations. It is designed to reduce manual steps, minimize potential errors, and enforce security best practices. The script supports two primary workflows: generating new keys from scratch and loading pre-existing keys from a backup.

### Purpose and Capabilities

This script provides comprehensive automation for configuring YubiKey 5 NFC devices with SSH and GPG keys. It implements security best practices including touch-to-confirm policies, proper key hierarchy, and automated backup procedures. The primary goals are to streamline YubiKey configuration, support multiple workflows, enforce security standards, maintain compatibility with modern FIDO2 SSH keys and universal GPG authentication, and enable automatic Git commit signing.

### Key Features

- **Automated YubiKey Initialization**: Sets PINs and configures touch policies
- **Triple-Mode Operation**: Supports generating new keys, loading existing keys, and backing up YubiKey
- **GPG Key Management**: Creates a standard GPG key hierarchy (master key with signing, encryption, and authentication subkeys) and transfers the subkeys to the YubiKey using reliable expect-based automation
- **Robust Key Transfer**: Uses expect automation with ANSI escape sequence handling and automatic GPG daemon restart to ensure reliable key transfers
- **Comprehensive Verification**: Validates all keys are properly transferred to YubiKey before creating backups, with detailed error diagnostics and automatic retry logic
- **SSH Configuration**: Generates FIDO2 resident SSH keys and configures the GPG agent for SSH authentication
- **Git Integration**: Automatically configures Git for commit and tag signing with the GPG key
- **Secure Backups**: Creates timestamped backups only after successful key verification, with clear documentation of what's backed up
- **Security Focused**: Implements best practices including touch-to-confirm policies, PIN protection, mandatory verification, and detailed audit logging
- **Reliable Operation**: Includes automatic daemon restart and retry logic to handle transient GPG agent and scdaemon issues

### Target Users

This script is designed for system administrators managing multiple YubiKeys, developers requiring hardware-backed SSH authentication, security-conscious users implementing zero-trust architectures, and teams standardizing on YubiKey-based authentication.

---

## 2. Installation

### Dependencies

Before running the script, ensure the following dependencies are installed on your system.

#### Required Dependencies

| Dependency | Minimum Version | Purpose |
|------------|----------------|---------|
| `gpg` (GnuPG) | 2.2.0 | GPG key generation and management |
| `ykman` (YubiKey Manager) | 4.0.0 | YubiKey configuration and management |
| `ssh-keygen` (OpenSSH) | 8.2 | FIDO2 SSH key generation |
| `expect` | Any | Automated interactive key transfer to YubiKey |
| `pinentry` | Any variant | Secure PIN entry for GPG operations |

#### Optional Dependencies

| Dependency | Minimum Version | Purpose |
|------------|----------------|---------|
| `git` | 2.0 | Automatic Git signing configuration |
| `qrencode` | Any | QR code generation of public keys |

#### Platform Support

- **Linux**: All major distributions (Ubuntu, Fedora, Arch, Debian)
- **macOS**: 10.15 (Catalina) and later
- **Windows**: WSL2 (Windows Subsystem for Linux 2)

### Installation Steps

**Step 1: Clone the Repository**

If you haven't already, clone the `home-lab` repository:

```bash
gh repo clone enuno/home-lab
```

**Step 2: Navigate to the Script Directory**

```bash
cd home-lab/scripts/yubikey-tools
```

**Step 3: Make the Script Executable**

```bash
chmod +x yubikey-setup.sh
```

**Step 4: Verify Dependencies**

The script will automatically check for required dependencies when run, but you can manually verify them:

```bash
# Check GPG
gpg --version

# Check YubiKey Manager
ykman --version

# Check SSH keygen
ssh-keygen -V

# Check expect
expect -version

# Check Git (optional)
git --version
```

**Installing expect**:
- **macOS**: `brew install expect`
- **Ubuntu/Debian**: `sudo apt-get install expect`
- **Fedora/RHEL**: `sudo yum install expect`
- **Arch**: `sudo pacman -S expect`

---

## 3. Quick Start

### Interactive Mode (Recommended for First-Time Users)

For first-time users, the interactive mode provides a guided setup experience. Simply run the script without any arguments:

```bash
./yubikey-setup.sh
```

The script will prompt you to choose an operation mode and guide you through the necessary steps.

### Non-Interactive Mode: Generate New Keys

To generate new keys for a new YubiKey setup without interactive prompts:

```bash
./yubikey-setup.sh --mode generate --name "John Doe" --email "john@example.com" --yes
```

### Non-Interactive Mode: Load Existing Keys

To load keys from a backup onto a new or secondary YubiKey:

```bash
./yubikey-setup.sh --mode load --backup /path/to/yubikey-backup-YYYY-MM-DD-HHMMSS --yes
```

### Non-Interactive Mode: Backup Existing YubiKey

To create a backup of keys already on a YubiKey:

```bash
./yubikey-setup.sh --mode backup --yes
```

---

## 4. Detailed Usage

The script can be customized with the following command-line arguments:

```
Usage: yubikey-setup.sh [OPTIONS]

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
```

### Usage Examples

**Example 1: Interactive Setup**

```bash
./yubikey-setup.sh
```

**Example 2: Generate New RSA Keys**

```bash
./yubikey-setup.sh --mode generate --name "Jane Smith" --email "jane@example.com" --key-type rsa4096
```

**Example 3: Generate New Ed25519 Keys**

```bash
./yubikey-setup.sh --mode generate --name "Jane Smith" --email "jane@example.com" --key-type ed25519
```

**Example 4: Load Keys from Backup**

```bash
./yubikey-setup.sh --mode load --backup ~/yubikey-backups/yubikey-backup-2025-10-23-120000
```

**Example 5: Generate Keys Without SSH Configuration**

```bash
./yubikey-setup.sh --mode generate --name "John Doe" --email "john@example.com" --skip-ssh
```

**Example 6: Verbose Output for Debugging**

```bash
./yubikey-setup.sh --mode generate --name "John Doe" --email "john@example.com" --verbose
```

**Example 7: Backup Existing YubiKey**

```bash
./yubikey-setup.sh --mode backup
```

---

## 5. Operational Modes

The script operates in three distinct modes, each designed for specific use cases.

### Mode 1: Generate New Keys (`generate`)

This mode is intended for a first-time setup of a YubiKey. It performs a complete configuration from scratch, generating all necessary keys on the system and transferring them to the YubiKey.

#### Workflow

The generate mode executes the following steps in sequence:

1. **Detect YubiKey**: Ensures a YubiKey is connected and recognized by the system
2. **Initialize YubiKey**: Resets the OpenPGP applet, sets new User and Admin PINs, and applies the specified touch policy
3. **Generate GPG Keys**: Creates a new GPG master key (for certification) and three subkeys (for signing, encryption, and authentication)
4. **Transfer Subkeys**: Moves the newly generated GPG subkeys to the YubiKey using expect-based automation (destructive operation)
5. **Verify Key Transfer**: Validates all three keys are properly loaded on YubiKey before proceeding (see Verification section below)
6. **Generate SSH Key**: Creates a FIDO2 resident SSH key (`ecdsa-sk`) on the YubiKey
7. **Configure GPG Agent**: Sets up the GPG agent to provide SSH authentication using the GPG authentication subkey
8. **Configure Git**: Sets up global Git configuration to use the new GPG key for signing commits and tags
9. **Create Backup**: Generates a comprehensive, timestamped backup only after successful key verification
10. **Verify Functionality**: Performs final checks to ensure all components are working correctly

#### Use Cases

- First-time YubiKey setup
- Replacing compromised keys
- Provisioning new team members
- Testing and development environments

#### Important Notes

The transfer of GPG subkeys to the YubiKey is a **destructive operation**. The private subkey material is removed from your computer's keyring and resides only on the YubiKey. This is why creating a secure backup is critical.

### Mode 2: Load Pre-existing Keys (`load`)

This mode is used to configure a new or secondary YubiKey using an existing backup. It is ideal for disaster recovery scenarios or setting up multiple YubiKeys with the same keys.

#### Workflow

The load mode executes the following steps in sequence:

1. **Detect YubiKey**: Ensures a YubiKey is connected and recognized by the system
2. **Initialize YubiKey**: Resets the OpenPGP applet and sets new User and Admin PINs
3. **Import GPG Keys**: Imports the GPG master key from the specified backup location
4. **Transfer Subkeys**: Moves the existing GPG subkeys to the YubiKey using expect-based automation (destructive operation)
5. **Verify Key Transfer**: Validates all three keys are properly loaded on YubiKey before proceeding
6. **Configure GPG Agent**: Sets up the GPG agent for SSH authentication
7. **Configure Git**: Sets up global Git configuration for commit signing
8. **Verify Functionality**: Performs final checks to ensure the loaded keys are functional

#### Use Cases

- Setting up backup or secondary YubiKey
- Migrating keys to new YubiKey after loss or damage
- Distributing organizational keys to team members
- Disaster recovery scenarios

#### Important Notes

When loading existing keys, ensure that you have a secure backup of the GPG master key. The script expects the backup to be in a specific format (either a directory with standard filenames or a single GPG key file).

### Mode 3: Backup Existing YubiKey (`backup`)

This mode creates a backup of public keys and configuration from a YubiKey that already has keys loaded on it. Note that private keys cannot be exported from YubiKey hardware - this backup only contains public keys and stubs.

#### Workflow

The backup mode executes the following steps in sequence:

1. **Detect YubiKey**: Ensures a YubiKey is connected and recognized by the system
2. **Verify Keys Present**: Checks that all three key slots (signature, encryption, authentication) have keys loaded
3. **Extract Card Information**: Retrieves cardholder name, email, and key ID from the YubiKey
4. **Display Current Status**: Shows comprehensive card status and key information
5. **Create Public Key Backup**: Exports public keys, card configuration, and YubiKey status
6. **Generate Documentation**: Creates README and documentation explaining backup contents

#### Use Cases

- Creating backups of public keys for distribution
- Documenting YubiKey configuration
- Backing up public keys before key rotation
- Creating reference documentation for key management

#### Important Notes

**What is backed up:**
- ✓ GPG public key
- ✓ GPG subkey stubs (references to hardware keys)
- ✓ SSH public keys (if available)
- ✓ YubiKey configuration and status

**What is NOT backed up (hardware-protected):**
- ✗ Private keys (stored securely on YubiKey chip and cannot be exported)
- ✗ PINs (never exported for security)

This mode is useful for distributing public keys or documenting your YubiKey setup, but it does not provide a complete restore capability since private keys remain on the hardware.

---

## 6. Configuration Options

### Key Types

The script supports two key types for GPG key generation:

#### RSA 4096-bit (Default)

RSA 4096-bit keys provide strong security and are widely supported across all platforms and services. This is the recommended option for maximum compatibility.

**Key Specifications:**
- **Master Key**: RSA 4096-bit, certification capability only
- **Signing Subkey**: RSA 4096-bit, expires 2 years
- **Encryption Subkey**: RSA 4096-bit, expires 2 years
- **Authentication Subkey**: RSA 4096-bit, expires 2 years

#### Ed25519 (Modern Alternative)

Ed25519 keys are based on elliptic curve cryptography and offer similar security to RSA 4096-bit keys but with smaller key sizes and faster operations. However, they may have limited support on older systems.

**Key Specifications:**
- **Master Key**: Ed25519, certification capability only
- **Signing Subkey**: Ed25519, expires 2 years
- **Encryption Subkey**: Curve25519, expires 2 years
- **Authentication Subkey**: Ed25519, expires 2 years

### Touch Policies

Touch policies determine when physical interaction with the YubiKey is required for cryptographic operations.

| Policy | Description | Security Level | Use Case |
|--------|-------------|----------------|----------|
| `on` (default) | Touch required for every operation | High | Maximum security; prevents silent key usage |
| `off` | No touch required | Low | Convenience over security; not recommended |
| `fixed` | Touch required, cannot be changed | Very High | Permanent security enforcement |
| `cached` | Touch required once per session (15 seconds) | Medium | Balance between security and convenience |

**Recommendation**: Use `on` for maximum security. This prevents malware from silently using your keys without your knowledge.

### SSH Configuration

The script generates FIDO2 resident SSH keys by default. These keys are stored directly on the YubiKey and require physical touch for authentication.

**SSH Key Specifications:**
- **Type**: `ecdsa-sk` (ECDSA over secp256k1)
- **Storage**: Resident key on YubiKey
- **Verification**: PIN required for each use

### YubiKey PIN Settings

The script configures two PINs for the YubiKey:

- **User PIN**: 6-8 digits, used for regular cryptographic operations (signing, encryption, authentication)
- **Admin PIN**: 8 digits, used for administrative tasks (changing PINs, resetting the device)

**Default PINs** (changed by the script):
- User PIN: `123456`
- Admin PIN: `12345678`

**PIN Retry Counter**: 5 attempts before the device locks

---

## 7. Key Transfer and Verification

### Expect-Based Key Transfer

The script uses `expect` (a tool for automating interactive programs) to handle the GPG key transfer process. This approach is necessary because GPG's `--edit-key` interface with `keytocard` commands requires interactive input that cannot be reliably automated with simple heredocs or pipes.

#### How It Works

1. **Expect Script Generation**: Creates a temporary expect script that automates the interactive GPG session
2. **Terminal Configuration**: Sets `TERM=dumb` to disable ANSI escape sequences (bracketed paste mode) that can interfere with pattern matching
3. **Interactive Automation**: The script:
   - Spawns `gpg --expert --edit-key <KEY_ID>` with dumb terminal
   - Uses flexible regex patterns (`expect -re "gpg>.*"`) to handle any remaining escape sequences
   - Selects each subkey (`key 1`, `key 2`, `key 3`)
   - Executes `keytocard` command for each
   - Selects the appropriate slot (1=signature, 2=encryption, 3=authentication)
   - Provides Admin PIN when prompted using flexible pattern matching
   - Handles YubiKey touch confirmations
   - Saves and exits with proper EOF handling
4. **Daemon Restart**: Automatically restarts GPG daemons after key transfer to clear any stale state
5. **Cleanup**: Removes the temporary expect script after completion

#### Why Expect?

Previous approaches using custom pinentry scripts failed because:
- GPG cannot access `/dev/tty` in non-interactive environments
- Heredoc and pipe combinations don't handle GPG's interactive prompts reliably
- GPG agent's pinentry protocol requires proper TTY allocation
- ANSI escape sequences (bracketed paste mode) interfere with simple pattern matching

The expect-based solution provides a real pseudo-TTY and properly handles all interactive prompts, with robust pattern matching and automatic error recovery.

#### Recent Improvements

- **ANSI Escape Handling**: Uses `TERM=dumb` and regex patterns to handle terminal escape sequences
- **Flexible Pattern Matching**: Updated from exact string matches to regex patterns for better reliability
- **Automatic Recovery**: Restarts GPG daemons after key transfer to prevent "broken pipe" errors
- **Extended Timeout**: Increased timeout to 120 seconds for slower systems or large keys
- **Better Error Messages**: Provides clear diagnostic output when operations fail

### Comprehensive Verification

After key transfer, the script performs mandatory verification before creating any backups or proceeding with configuration.

#### Verification Process

1. **Card Status Check**: Runs `gpg --card-status` to retrieve current YubiKey state
2. **Key Slot Validation**: Verifies each of the three key slots:
   - Signature key slot (must not be `[none]`)
   - Encryption key slot (must not be `[none]`)
   - Authentication key slot (must not be `[none]`)
3. **Key File Analysis**: Checks `~/.gnupg/private-keys-v1.d/` for key files:
   - Files >500 bytes = full private keys (transfer failed)
   - Files <500 bytes = stubs (transfer succeeded)

#### If Verification Fails

The script provides a detailed error report including:

**Diagnostic Information:**
- Full GPG card status output
- List of key files with sizes (stub vs full key detection)
- Key ID and fingerprint information

**Possible Causes:**
1. YubiKey touch policy requires physical touch (user didn't touch the key)
2. Admin PIN was incorrect or not accepted
3. YubiKey is locked or has PIN retry counter at 0
4. Expect script timed out or encountered unexpected prompts
5. GPG version incompatibility

**Troubleshooting Steps:**
1. Check YubiKey PIN retry counter: `gpg --card-status | grep 'PIN retry counter'`
2. Verify YubiKey is properly connected: `ykman list`
3. Try the transfer manually: `gpg --expert --edit-key <KEY_ID>`
4. Check the log file for details: `/tmp/yubikey-setup-*.log`

**Script Behavior on Failure:**
- **Exits immediately** with error status
- **No backup is created** (prevents false sense of security)
- **Detailed diagnostics** help identify the root cause
- **Log file** contains full command output for debugging

#### Security Benefits

The mandatory verification ensures:
- Keys are actually on hardware before backup creation
- No false sense of security from incomplete transfers
- Clear indication of success or failure
- Detailed diagnostics for troubleshooting
- Prevents backing up systems where private keys remain on disk

---

## 8. How the Script Functions

The script is organized into several modules, each responsible for a specific part of the configuration process. Understanding these modules helps in troubleshooting and customization.

### Architecture Overview

The script follows a modular architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────┐
│         Main Workflow Controller            │
│  (mode_generate / mode_load / interactive)  │
└─────────────────┬───────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│ Helper  │  │ YubiKey │  │   GPG   │
│Functions│  │ Config  │  │  Keys   │
└─────────┘  └─────────┘  └─────────┘
    │             │             │
    └─────────────┼─────────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│   SSH   │  │   Git   │  │ Backup  │
│ Config  │  │ Config  │  │Recovery │
└─────────┘  └─────────┘  └─────────┘
```

### Module Descriptions

#### 1. Helper Functions Module

This module provides core utilities used throughout the script:

- **Color Output Functions**: `log_info()`, `log_success()`, `log_warning()`, `log_error()`, `log_debug()`, `log_step()` provide colorized terminal output for better user experience
- **Command Validation**: `command_exists()` checks if required binaries are available
- **Prerequisite Checking**: `check_prerequisites()` validates all dependencies before execution
- **YubiKey Detection**: `detect_yubikey()` ensures a YubiKey is connected
- **User Confirmation**: `confirm_operation()` prompts for explicit user consent before destructive operations
- **Secure Input**: `read_pin()` handles secure PIN entry without echoing to the terminal
- **Email Validation**: `validate_email()` ensures email addresses are properly formatted

#### 2. YubiKey Configuration Module

This module handles low-level interactions with the YubiKey:

- **OpenPGP Applet Reset**: Uses `ykman openpgp reset` to clear existing configuration
- **PIN Management**: Sets User PIN and Admin PIN through GPG card-edit interface
- **Touch Policy Configuration**: Uses `ykman openpgp keys set-touch` to configure touch requirements for signing, encryption, and authentication operations
- **Cardholder Information**: Sets up metadata on the YubiKey card

The module interacts with the YubiKey through two primary tools: `ykman` (YubiKey Manager CLI) for high-level operations and `gpg --card-edit` for GPG-specific configuration.

#### 3. GPG Key Management Module

This module manages the creation and importation of GPG keys:

**In Generate Mode:**
- Creates a batch file with key specifications (algorithm, key length, usage flags)
- Uses `gpg --batch --generate-key` to create the master key and subkeys
- Generates a proper key hierarchy with a certification-only master key and separate subkeys for signing, encryption, and authentication
- Stores the key ID for subsequent operations

**In Load Mode:**
- Validates the backup path and locates key files
- Uses `gpg --import` to import the master key and public key
- Extracts the key ID from the imported keys

**Key Transfer:**
- Uses the `keytocard` command in GPG's edit-key interface to move subkeys to the YubiKey
- Transfers signing subkey to slot 1
- Transfers encryption subkey to slot 2
- Transfers authentication subkey to slot 3

#### 4. SSH Configuration Module

This module configures SSH authentication:

**FIDO2 Key Generation:**
- Uses `ssh-keygen -t ecdsa-sk -O resident -O verify-required` to create a FIDO2 resident key
- The `-O resident` flag stores the key on the YubiKey
- The `-O verify-required` flag enforces PIN entry for each use

**GPG Agent Configuration:**
- Modifies `~/.gnupg/gpg-agent.conf` to enable SSH support
- Restarts the GPG agent to apply changes
- Configures shell RC files (`.bashrc` or `.zshrc`) to set environment variables (`GPG_TTY`, `SSH_AUTH_SOCK`)
- Exports the GPG authentication subkey as an SSH public key

#### 5. Git Integration Module

This module configures Git for automatic commit signing:

- Sets `user.signingkey` to the GPG key ID
- Enables `commit.gpgsign` for automatic commit signing
- Enables `tag.gpgsign` for automatic tag signing
- Sets `gpg.program` to the correct GPG binary path
- Optionally sets `user.name` and `user.email` if provided

All configuration is applied globally using `git config --global`.

#### 6. Backup and Recovery Module

This module creates comprehensive backups:

**Backup Structure:**
```
yubikey-backup-YYYY-MM-DD-HHMMSS/
├── README.txt                    # Backup metadata and instructions
├── gpg-master-key.asc            # Encrypted master private key
├── gpg-public-key.asc            # Public key export
├── gpg-subkeys.asc               # Subkeys backup (before transfer)
├── ssh-fido2-public.pub          # FIDO2 SSH public key
├── ssh-gpg-public.pub            # GPG authentication public key
├── yubikey-status.txt            # YubiKey configuration snapshot
└── restore-instructions.txt      # Detailed restoration guide
```

**Backup Operations:**
- Uses `gpg --export-secret-keys` to export the master key
- Uses `gpg --export` to export the public key
- Uses `gpg --export-secret-subkeys` to export subkeys
- Copies SSH public keys from `~/.ssh/`
- Captures YubiKey status using `ykman info` and `gpg --card-status`
- Generates README and restoration instructions

#### 7. Verification and Testing Module

This module performs post-configuration checks:

- Displays YubiKey information using `ykman info`
- Shows GPG card status using `gpg --card-status`
- Tests GPG signing with `echo "test" | gpg --clearsign`
- Lists SSH keys using `ssh-add -L`
- Logs all results for troubleshooting

### Execution Flow

**Generate Mode Flow:**
```
Start → Check Prerequisites → Detect YubiKey → Initialize YubiKey →
Generate GPG Keys → Transfer Subkeys (expect) → Verify Keys on YubiKey →
[If verification fails: Exit with detailed error] →
[If verification succeeds:] Generate SSH Keys → Configure GPG Agent →
Configure Git → Create Backup → Final Verification → End
```

**Load Mode Flow:**
```
Start → Check Prerequisites → Detect YubiKey → Initialize YubiKey →
Import GPG Keys → Transfer Subkeys (expect) → Verify Keys on YubiKey →
[If verification fails: Exit with detailed error] →
[If verification succeeds:] Configure GPG Agent → Configure Git →
Final Verification → End
```

**Backup Mode Flow:**
```
Start → Check Prerequisites → Detect YubiKey → Check Keys Present →
[If no keys: Exit with error] →
[If keys present:] Extract Card Info → Display Status →
Create Public Key Backup → Generate Documentation → End
```

### Logging and Error Handling

The script implements comprehensive logging and error handling:

- All operations are logged to `/tmp/yubikey-setup-YYYYMMDD-HHMMSS.log`
- The script uses `set -euo pipefail` for strict error handling
- A trap is set to catch errors and log the failing line number
- User-friendly error messages are displayed with remediation steps
- Critical operations require explicit user confirmation

---

## 8. Security Considerations

### Threat Model

#### Protected Against

- **Remote Key Theft**: Private keys never leave the YubiKey after transfer
- **Silent Key Usage**: Touch requirement prevents malware from using keys without physical interaction
- **Brute-Force Attacks**: PIN retry limits (5 attempts) prevent brute-force PIN guessing
- **Physical Theft with Limited Impact**: PIN protection provides a layer of defense even if the YubiKey is stolen

#### Not Protected Against

- **Shoulder Surfing**: Physical observation during PIN entry
- **Compromised Host During Key Generation**: If the system is compromised during initial key generation, keys may be intercepted before transfer
- **Physical Access to Backup Files**: Backups contain the master key and must be secured
- **Coerced PIN Disclosure**: Physical threats or legal compulsion to reveal PINs

### Best Practices

#### During Setup

1. **Use a Trusted System**: Generate keys on a trusted, preferably air-gapped system
2. **Strong PINs**: Use strong, unique PINs for both User and Admin
3. **Verify YubiKey**: Ensure you're using a genuine YubiKey from a trusted source
4. **Secure Environment**: Perform setup in a private environment free from observation

#### After Setup

1. **Secure Backups**: Store backups encrypted on offline, physically secure media (e.g., encrypted USB drive in a safe)
2. **Test Restoration**: Regularly test backup restoration procedures to ensure they work
3. **Avoid Untrusted Systems**: Never use your YubiKey on untrusted computers
4. **Replace if Compromised**: If your YubiKey is lost or potentially compromised, immediately revoke keys and generate new ones
5. **Monitor Usage**: Regularly review Git commit signatures and SSH authentication logs

#### Backup Security

The generated backup contains your GPG master key, which is the most sensitive component. **Anyone with access to this backup can impersonate you.** Follow these guidelines:

- **Encrypt the Backup**: Use strong encryption (e.g., VeraCrypt, LUKS) for the backup directory
- **Offline Storage**: Store backups on offline media, not cloud storage
- **Physical Security**: Keep backups in a physically secure location (safe, safety deposit box)
- **Multiple Copies**: Maintain multiple backup copies in different secure locations
- **Test Regularly**: Periodically verify that backups can be successfully restored

### Critical Operations Requiring Explicit Consent

The script warns and requires confirmation before:

1. Overwriting existing YubiKey configuration
2. Transferring keys to YubiKey (destructive move)
3. Changing PINs
4. Resetting YubiKey to factory defaults

---

## 9. Troubleshooting

### Common Issues and Solutions

#### Issue: "No YubiKey detected"

**Symptom**: The script reports that no YubiKey is connected.

**Possible Causes**:
- YubiKey is not inserted
- USB connection issue
- YubiKey Manager (`ykman`) not installed or not in PATH

**Solution**:
1. Ensure your YubiKey is properly inserted
2. Try a different USB port
3. Run `ykman list` to verify detection
4. On Linux, check USB permissions and udev rules
5. Restart the `pcscd` service: `sudo systemctl restart pcscd`

#### Issue: GPG Agent Connection Problems

**Symptom**: GPG operations fail with "agent connection failed" or similar errors.

**Possible Causes**:
- GPG agent not running
- Incorrect socket configuration
- Conflicting GPG agent instances

**Solution**:
1. Kill and restart the GPG agent: `gpgconf --kill gpg-agent`
2. Check GPG agent status: `gpg-agent --daemon --enable-ssh-support`
3. Verify socket location: `gpgconf --list-dirs agent-socket`
4. Check `~/.gnupg/gpg-agent.conf` for correct configuration

#### Issue: scdaemon "Broken Pipe" Error

**Symptom**: After key transfer operations, GPG card status shows "Broken pipe" or "OpenPGP card not available" errors.

**What This Means**: The scdaemon (Smart Card Daemon) has crashed or become unresponsive after intensive card operations.

**Automatic Handling**: The script now automatically handles this by:
- Restarting GPG daemons immediately after key transfer
- Implementing retry logic in verification steps (up to 3 attempts)
- Providing automatic recovery in the final verification stage

**Manual Solution** (if needed):
1. Kill all GPG-related daemons: `gpgconf --kill gpg-agent && gpgconf --kill scdaemon`
2. Wait a moment: `sleep 2`
3. Let daemons auto-restart: `gpgconf --launch gpg-agent`
4. Try the operation again: `gpg --card-status`

**Prevention**: The script's automatic restart logic should prevent this error in normal operation.

#### Issue: SSH Authentication Failures

**Symptom**: SSH authentication using the YubiKey fails.

**Possible Causes**:
- SSH public key not added to remote server
- `SSH_AUTH_SOCK` environment variable not set correctly
- GPG agent not providing SSH support

**Solution**:
1. Verify public key on remote server: Check `~/.ssh/authorized_keys` on the remote host
2. Check environment variable: `echo $SSH_AUTH_SOCK` should point to GPG agent socket
3. List available keys: `ssh-add -L`
4. Source your shell RC file: `source ~/.bashrc` or `source ~/.zshrc`
5. Manually set the socket: `export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)`

#### Issue: Git Signing Errors

**Symptom**: Git commits fail to sign or show "gpg failed to sign the data" error.

**Possible Causes**:
- GPG key not configured in Git
- GPG agent not running
- Incorrect GPG program path

**Solution**:
1. Verify Git configuration: `git config --global --list | grep gpg`
2. Check signing key: `git config --global user.signingkey`
3. Test GPG signing: `echo "test" | gpg --clearsign`
4. Disable signing temporarily: `git commit --no-gpg-sign`
5. Reconfigure Git: Run the script's Git configuration section again

#### Issue: PIN Blocked

**Symptom**: YubiKey reports that the PIN is blocked after too many incorrect attempts.

**Possible Causes**:
- Incorrect PIN entered multiple times
- PIN retry counter exhausted

**Solution**:
1. Use the Admin PIN to reset the User PIN: `gpg --card-edit` then `admin` then `passwd`
2. If Admin PIN is also blocked, reset the YubiKey: `ykman openpgp reset` (WARNING: This deletes all keys)
3. Restore from backup after reset

#### Issue: Touch Not Required

**Symptom**: Cryptographic operations succeed without touching the YubiKey.

**Possible Causes**:
- Touch policy not set correctly
- Touch policy set to `off` or `cached`

**Solution**:
1. Check current touch policy: `ykman openpgp info`
2. Set touch policy: `ykman openpgp keys set-touch sig on -a ADMIN_PIN`
3. Repeat for encryption and authentication: `enc` and `aut`

#### Issue: Key Transfer Verification Failed

**Symptom**: Script reports "Key transfer verification FAILED!" and exits without creating backup.

**What This Means**: The GPG subkeys were not successfully transferred to the YubiKey. The verification detected that either:
- One or more key slots on the YubiKey are empty (`[none]`)
- The private key files on disk are still full keys (>500 bytes) instead of stubs

**Diagnostic Output**: The script provides a detailed error report showing:
- Full card status from `gpg --card-status`
- Key file sizes in `~/.gnupg/private-keys-v1.d/`
- Analysis of which keys succeeded/failed

**Common Causes and Solutions**:

1. **YubiKey Touch Required But Not Performed**
   - **Cause**: Touch policy is set to `on` but you didn't touch the YubiKey during transfer
   - **Solution**: Re-run the script and touch the YubiKey when prompted during key transfer

2. **Incorrect Admin PIN**
   - **Cause**: The Admin PIN was entered incorrectly or doesn't match what's set on the YubiKey
   - **Solution**: Verify your Admin PIN is correct, check retry counter: `gpg --card-status | grep 'PIN retry counter'`

3. **PIN Retry Counter Exhausted**
   - **Cause**: Too many incorrect PIN attempts have locked the YubiKey
   - **Solution**: Reset with correct Admin PIN or factory reset: `ykman openpgp reset -f` (WARNING: deletes all keys)

4. **Expect Script Timeout**
   - **Cause**: The interactive session timed out (default 60 seconds)
   - **Solution**: Check the log file `/tmp/yubikey-setup-*.log` for timeout errors

5. **GPG Agent Issues**
   - **Cause**: GPG agent not responding or in bad state
   - **Solution**: Kill and restart GPG agent: `gpgconf --kill gpg-agent`

**Prevention**:
- Use the script in a stable environment with reliable USB connection
- Respond promptly to YubiKey touch prompts
- Ensure correct PINs before starting
- Check YubiKey retry counters before running: `gpg --card-status`

**Manual Verification**:
To manually check if keys transferred successfully:
```bash
# Check card status
gpg --card-status

# Look for key fingerprints (not [none]) in:
# - Signature key .....
# - Encryption key....
# - Authentication key

# Check key files (should be stubs <500 bytes)
ls -lh ~/.gnupg/private-keys-v1.d/
```

#### Issue: Backup Import Fails

**Symptom**: The script cannot import keys from a backup.

**Possible Causes**:
- Incorrect backup path
- Backup files corrupted or missing
- Backup format not recognized

**Solution**:
1. Verify backup path exists: `ls -la /path/to/backup`
2. Check for required files: `gpg-master-key.asc` should be present
3. Manually import: `gpg --import /path/to/backup/gpg-master-key.asc`
4. Verify key import: `gpg --list-secret-keys`

### Platform-Specific Issues

#### Linux

- **udev Rules**: Ensure YubiKey udev rules are installed: `/etc/udev/rules.d/70-yubikey.rules`
- **pcscd Service**: The PC/SC daemon must be running: `sudo systemctl start pcscd`

#### macOS

- **Homebrew Dependencies**: Install dependencies via Homebrew: `brew install gnupg yubikey-manager pinentry-mac`
- **GPG Agent**: May need to configure `pinentry-program` in `~/.gnupg/gpg-agent.conf` to point to `pinentry-mac`

#### Windows (WSL2)

- **USB Passthrough**: YubiKey must be passed through to WSL2 using `usbipd`
- **Windows GPG Conflict**: Disable Windows GPG if it conflicts with WSL GPG

---

## 10. Backup and Recovery

### Backup Structure and Contents

The script creates a comprehensive backup directory with the following structure:

```
yubikey-backup-YYYY-MM-DD-HHMMSS/
├── README.txt                    # Backup metadata and instructions
├── gpg-master-key.asc            # GPG master private key (CRITICAL)
├── gpg-public-key.asc            # GPG public key (safe to share)
├── gpg-subkeys.asc               # GPG subkeys backup
├── ssh-fido2-public.pub          # FIDO2 SSH public key
├── ssh-gpg-public.pub            # GPG authentication public key for SSH
├── yubikey-status.txt            # YubiKey configuration snapshot
└── restore-instructions.txt      # Detailed restoration guide
```

### Backup Security

**Critical Files:**
- `gpg-master-key.asc`: Contains your private master key. **Must be kept absolutely secure.**

**Public Files (Safe to Share):**
- `gpg-public-key.asc`: Your public key, safe to distribute
- `ssh-fido2-public.pub`: SSH public key, add to servers
- `ssh-gpg-public.pub`: GPG-based SSH public key, add to servers

### Restoration Procedures

#### Scenario 1: Lost or Damaged YubiKey

If your YubiKey is lost or damaged, you can restore your keys to a new YubiKey using the backup:

```bash
./yubikey-setup.sh --mode load --backup ~/yubikey-backups/yubikey-backup-YYYY-MM-DD-HHMMSS
```

#### Scenario 2: Setting Up a Secondary YubiKey

To set up a second YubiKey with the same keys (for backup purposes):

```bash
./yubikey-setup.sh --mode load --backup ~/yubikey-backups/yubikey-backup-YYYY-MM-DD-HHMMSS
```

#### Scenario 3: Manual Key Restoration

If you need to manually restore keys without using the script:

1. **Import the master key**:
   ```bash
   gpg --import ~/yubikey-backups/yubikey-backup-YYYY-MM-DD-HHMMSS/gpg-master-key.asc
   ```

2. **Import the public key**:
   ```bash
   gpg --import ~/yubikey-backups/yubikey-backup-YYYY-MM-DD-HHMMSS/gpg-public-key.asc
   ```

3. **Verify import**:
   ```bash
   gpg --list-secret-keys
   ```

4. **Transfer to YubiKey**:
   Use the script in load mode or manually use `gpg --edit-key` with `keytocard` commands.

### Testing Backup Integrity

Regularly test your backups to ensure they can be successfully restored:

1. **Verify backup files exist**:
   ```bash
   ls -la ~/yubikey-backups/yubikey-backup-YYYY-MM-DD-HHMMSS/
   ```

2. **Test key import** (in a test environment):
   ```bash
   gpg --dry-run --import ~/yubikey-backups/yubikey-backup-YYYY-MM-DD-HHMMSS/gpg-master-key.asc
   ```

3. **Perform full restoration test** (on a test YubiKey):
   ```bash
   ./yubikey-setup.sh --mode load --backup ~/yubikey-backups/yubikey-backup-YYYY-MM-DD-HHMMSS
   ```

---

## 11. Contributing

Contributions to improve this script are welcome. Please follow these guidelines:

### Reporting Issues

If you encounter a bug or have a feature request:

1. Check existing issues in the repository
2. Provide detailed information about your environment (OS, versions of dependencies)
3. Include relevant log files (`/tmp/yubikey-setup-*.log`)
4. Describe the expected behavior and actual behavior

### Code Contributions

When contributing code:

1. **Follow the existing code style**: Use consistent formatting and naming conventions
2. **Add comments**: Explain complex operations and security considerations
3. **Test thoroughly**: Test on real hardware before submitting
4. **Update documentation**: Update this README if you add new features
5. **Security review**: Cryptographic operations require careful review

### Development Standards

- **Shellcheck Compliance**: All code must pass `shellcheck` static analysis
- **POSIX Compatibility**: Prefer POSIX-compliant syntax where possible
- **Error Handling**: Implement proper error handling with informative messages
- **Logging**: Log all operations for audit trails
- **Security First**: Never log sensitive information (PINs, private keys)

---

## License

This script is part of the `home-lab` repository. Please refer to the repository's LICENSE file for licensing information.

---

## Acknowledgments

This script was developed based on the comprehensive development plan outlined in `DEVELOPMENT_PLAN.md`. It implements security best practices from the YubiKey and GPG communities.

---

## Additional Resources

- [YubiKey Manager CLI Documentation](https://docs.yubico.com/software/yubikey/tools/ykman/)
- [GnuPG Documentation](https://gnupg.org/documentation/)
- [OpenSSH FIDO/U2F Support](https://www.openssh.com/txt/release-8.2)
- [Yubico Developer Program](https://developers.yubico.com/)

---

**Author**: Manus AI
**Version**: 1.1.0
**Last Updated**: October 26, 2025

## Changelog

### Version 1.1.0 (2025-10-26)

- **Fixed**: Resolved ANSI escape sequence handling in expect script that caused script to hang
- **Fixed**: Corrected expect script logic for final key transfer to prevent timeout
- **Added**: Automatic GPG daemon restart after key transfer to prevent "broken pipe" errors
- **Added**: Retry logic in key verification with up to 3 automatic retry attempts
- **Added**: Retry logic in final verification stage for better reliability
- **Improved**: Extended timeout from 60 to 120 seconds for key transfer operations
- **Improved**: Enhanced error messages and diagnostic output

### Version 1.0.0 (2025-10-24)

- Initial release with comprehensive YubiKey setup automation
- Support for generate, load, and backup operational modes
- Expect-based key transfer automation
- Comprehensive verification before backup creation
