# DEVELOPMENT_PLAN.md

## YubiKey SSH and GPG Key Management Script

**Repository**: `https://github.com/enuno/home-lab/scripts/`
**Script Name**: `yubikey-setup.sh`
**Purpose**: Automate YubiKey 5 NFC configuration for SSH authentication and GPG code signing with support for both new key generation and loading pre-existing keys.

---

## Project Overview

This script provides comprehensive automation for configuring YubiKey 5 NFC devices with SSH and GPG keys. It implements security best practices including touch-to-confirm policies, proper key hierarchy, and automated backup procedures.

### Primary Goals

1. **Streamline YubiKey Configuration**: Reduce manual steps and potential errors in YubiKey setup
2. **Support Multiple Workflows**: Enable both new key generation and loading existing keys
3. **Enforce Security Standards**: Implement touch policies, PIN protection, and secure key management
4. **Maintain Compatibility**: Support both modern FIDO2 SSH keys and universal GPG authentication
5. **Enable Code Signing**: Configure automatic Git commit signing with GPG keys

### Target Users

- System administrators managing multiple YubiKeys
- Developers requiring hardware-backed SSH authentication
- Security-conscious users implementing zero-trust architectures
- Teams standardizing on YubiKey-based authentication

---

## Operational Modes

The script will operate in two distinct modes, selectable via command-line argument or interactive prompt:

### Mode 1: Generate New Keys

**Purpose**: Complete setup from scratch, generating all keys on the system and transferring to YubiKey.

**Workflow**:
1. Initialize YubiKey (set PINs, configure touch policies)
2. Generate GPG master key and subkeys (signing, encryption, authentication)
3. Transfer GPG subkeys to YubiKey (destructive move)
4. Generate FIDO2 SSH resident keys on YubiKey
5. Configure GPG agent for SSH authentication
6. Set up Git commit signing
7. Create comprehensive backup

**Use Cases**:
- First-time YubiKey setup
- Replacing compromised keys
- Provisioning new team members
- Testing and development environments

### Mode 2: Load Pre-existing Keys

**Purpose**: Load previously generated GPG keys and SSH keys onto a YubiKey.

**Workflow**:
1. Initialize YubiKey (set PINs, configure touch policies)
2. Import existing GPG master key from backup
3. Transfer existing GPG subkeys to YubiKey
4. Load existing SSH keys (if FIDO2 resident keys, use backup; if GPG-based, use authentication subkey)
5. Configure GPG agent for SSH authentication
6. Set up Git commit signing with existing key
7. Verify key functionality

**Use Cases**:
- Setting up backup/secondary YubiKey
- Migrating keys to new YubiKey after loss/damage
- Distributing organizational keys to team members
- Disaster recovery scenarios

---

## Technical Architecture

### Core Components

#### 1. Helper Functions
- **Color Output**: Terminal formatting for user feedback
- **Command Validation**: Check for required binaries (gpg, ykman, ssh-keygen)
- **Error Handling**: Graceful failure with rollback capabilities
- **Logging**: Detailed operation logging for audit trails

#### 2. YubiKey Configuration Module
- PIN management (User PIN, Admin PIN)
- Touch policy enforcement (signing, encryption, authentication)
- Cardholder information setup
- PIN retry counter configuration
- YubiKey detection and validation

#### 3. GPG Key Management Module
- **Generation Mode**:
  - Master key creation (RSA 4096-bit, certification-only)
  - Subkey generation (signing, encryption, authentication)
  - Key hierarchy establishment
- **Import Mode**:
  - Backup file validation and parsing
  - Key import from encrypted archives
  - Subkey selection and preparation
- Key transfer to YubiKey (keytocard operation)
- Public key export and distribution

#### 4. SSH Configuration Module
- **FIDO2 Key Handling**:
  - New key generation with resident credentials
  - Existing key loading from backup
- **GPG Authentication Key**:
  - Configuration for SSH via GPG agent
  - Socket management and environment setup
- Shell RC file configuration (.bashrc, .zshrc)
- SSH agent integration

#### 5. Git Integration Module
- Signing key configuration
- Automatic commit/tag signing setup
- GPG program path configuration
- Verification testing

#### 6. Backup and Recovery Module
- **Generation Mode**: Create new backup archives
- **Import Mode**: Validate and restore from backups
- Timestamped backup directory structure
- Comprehensive metadata export
- Secure backup location recommendations

#### 7. Verification and Testing Module
- YubiKey communication tests
- GPG operation validation (sign, encrypt, decrypt)
- SSH authentication testing
- Git signing verification
- Touch policy confirmation

---

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1-2)

**Objectives**:
- Set up project structure and documentation
- Implement helper functions and error handling
- Create prerequisite validation system
- Develop YubiKey detection and initialization

**Deliverables**:
- Basic script skeleton with argument parsing
- Mode selection interface (CLI flags and interactive)
- Color-coded output system
- Prerequisite check module
- YubiKey basic configuration functions

**Testing Requirements**:
- Unit tests for helper functions
- YubiKey detection across different systems
- Error handling for missing dependencies
- User input validation

### Phase 2: Mode 1 Implementation - Generate New Keys (Week 3-4)

**Objectives**:
- Implement complete new key generation workflow
- Develop GPG key hierarchy creation
- Build YubiKey transfer mechanism
- Create FIDO2 SSH key generation

**Deliverables**:
- GPG master key generation function
- Subkey creation (signing, encryption, authentication)
- Automated keytocard transfer logic
- FIDO2 resident key generation
- Initial backup creation

**Testing Requirements**:
- End-to-end new key generation workflow
- Key hierarchy validation
- Touch policy enforcement testing
- FIDO2 key functionality verification
- Backup completeness checks

### Phase 3: Mode 2 Implementation - Load Existing Keys (Week 5-6)

**Objectives**:
- Develop backup import functionality
- Implement existing key loading mechanisms
- Create key restoration workflows
- Build secondary YubiKey provisioning

**Deliverables**:
- Backup file parser and validator
- GPG key import from encrypted archives
- Existing subkey transfer to YubiKey
- SSH key restoration logic
- Verification of loaded keys

**Testing Requirements**:
- Backup import with various formats
- Key loading from different sources
- Secondary YubiKey setup validation
- Cross-device key consistency checks
- Disaster recovery scenario testing

### Phase 4: SSH and Git Integration (Week 7)

**Objectives**:
- Complete SSH agent configuration
- Implement Git signing setup
- Develop shell integration
- Create verification tests

**Deliverables**:
- GPG agent SSH support configuration
- Shell RC file modification (bashrc/zshrc)
- Git global configuration for signing
- SSH public key export utilities
- Comprehensive test suite

**Testing Requirements**:
- SSH authentication via YubiKey
- Git commit signing functionality
- Multi-shell compatibility (bash, zsh, fish)
- Touch requirement during SSH operations
- Signed commit verification on GitHub/GitLab

### Phase 5: Backup, Recovery, and Documentation (Week 8)

**Objectives**:
- Finalize backup creation and restoration
- Complete comprehensive documentation
- Create troubleshooting guides
- Develop security hardening guidelines

**Deliverables**:
- Automated backup with encryption options
- Backup restoration procedures
- Complete README.md with usage examples
- Troubleshooting documentation
- Security best practices guide
- Video tutorial (optional)

**Testing Requirements**:
- Full backup and restore cycle
- Disaster recovery procedures
- Documentation accuracy verification
- Security audit

### Phase 6: Integration, Testing, and Release (Week 9-10)

**Objectives**:
- Perform comprehensive integration testing
- Conduct security review
- Create CI/CD pipeline
- Prepare release materials

**Deliverables**:
- Full integration test suite
- Security audit report
- CI/CD pipeline for automated testing
- Release notes and changelog
- Installation and upgrade guides
- Contributing guidelines

**Testing Requirements**:
- Cross-platform testing (Linux, macOS)
- Multiple YubiKey model testing
- Edge case and error condition testing
- Performance benchmarking
- User acceptance testing

---

## Development Standards

### Code Quality and Review

**Documentation Requirements**:
- Clear inline comments explaining complex operations
- Function-level documentation with purpose, parameters, and return values
- Security considerations for sensitive operations
- Examples for non-obvious usage patterns

**Code Review Process**:
- All code must pass static analysis (shellcheck)
- Peer review required for cryptographic operations
- Security review for PIN and key handling
- Manual testing on physical YubiKey before merge

**Testing Standards**:
- Unit tests for all utility functions
- Integration tests for complete workflows
- Manual verification on real hardware
- Regression testing for bug fixes
- Coverage target: 80%+ for testable functions

### Security Practices

**Key Management**:
- Never log sensitive information (PINs, private keys)
- Secure deletion of temporary files
- Encrypted backup creation with strong passphrases
- Clear warnings about irreversible operations

**Input Validation**:
- Sanitize all user inputs
- Validate file paths and permissions
- Check YubiKey state before operations
- Confirm destructive operations with explicit user consent

**Error Handling**:
- Graceful degradation on errors
- Clear error messages with remediation steps
- Rollback capabilities where possible
- Audit logging of all operations

### AI-Assisted Development Guidelines

When using AI coding assistants (Claude, Copilot, etc.) for this project:

**Prompt Engineering**:
- Always specify bash scripting with shellcheck compatibility
- Include security context for cryptographic operations
- Reference GPG and YubiKey API documentation
- Specify POSIX compliance requirements where applicable

**Code Validation**:
- Review all AI-generated cryptographic code manually
- Cross-reference with official YubiKey documentation
- Test AI-generated functions on non-production YubiKeys
- Validate against established security patterns

**Iteration and Refinement**:
- Request multiple implementation alternatives
- Ask for security considerations and edge cases
- Iterate on error handling and user feedback
- Refine based on real-world testing results

---

## Script Interface Design

### Command-Line Arguments

```bash
yubikey-setup.sh [OPTIONS]

Options:
  -m, --mode MODE          Operation mode: 'generate' or 'load' (default: interactive)
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
  -h, --help               Display help message
  --version                Display version information
```

### Interactive Mode Flow

**Initial Prompt**:
```
Welcome to YubiKey Setup Script
================================

This script will help you configure your YubiKey 5 NFC for SSH and GPG.

Select operation mode:
  1) Generate new keys (first-time setup)
  2) Load existing keys (backup/secondary YubiKey)

Enter selection [1-2]:
```

**Mode-Specific Prompts** (Generate):
```
Generate New Keys Mode
======================

Please provide the following information:
  - Full name: [input]
  - Email address: [input]
  - Key type (RSA 4096-bit recommended): [rsa4096/ed25519]
  - Touch policy (on recommended for security): [on/off/cached/fixed]

Create User PIN (6-8 digits): [hidden input]
Confirm User PIN: [hidden input]

Create Admin PIN (8 digits): [hidden input]
Confirm Admin PIN: [hidden input]

WARNING: This will generate NEW keys and transfer them to your YubiKey.
         Existing keys on the YubiKey will be OVERWRITTEN.

Continue? [y/N]:
```

**Mode-Specific Prompts** (Load):
```
Load Existing Keys Mode
========================

This mode will load pre-existing GPG keys onto your YubiKey.

Backup location: [path to backup directory or .gpg file]

Available keys found:
  1) John Doe <john@example.com> (RSA 4096, created 2024-10-15)
  2) Jane Smith <jane@example.com> (Ed25519, created 2024-09-20)

Select key to load [1-2]:

Create User PIN (6-8 digits): [hidden input]
Confirm User PIN: [hidden input]

Create Admin PIN (8 digits): [hidden input]
Confirm Admin PIN: [hidden input]

WARNING: This will MOVE subkeys to your YubiKey. Ensure you have secure backups.

Continue? [y/N]:
```

---

## Technical Specifications

### Dependencies

**Required**:
- `gpg` (GnuPG) >= 2.2.0
- `ykman` (YubiKey Manager) >= 4.0.0
- `ssh-keygen` (OpenSSH) >= 8.2 (for FIDO2 support)
- `pinentry` (any variant: curses, gnome, qt)

**Optional**:
- `git` >= 2.0 (for commit signing setup)
- `qrencode` (for QR code generation of public keys)

**Platform Support**:
- Linux (all major distributions)
- macOS 10.15+
- Windows with WSL2

### Key Specifications

**GPG Keys** (Default Configuration):
- **Master Key**: RSA 4096-bit, certification capability only
- **Signing Subkey**: RSA 4096-bit, expires 2 years
- **Encryption Subkey**: RSA 4096-bit, expires 2 years
- **Authentication Subkey**: RSA 4096-bit, expires 2 years

**Alternative Configuration** (Ed25519):
- **Master Key**: Ed25519, certification capability only
- **Signing Subkey**: Ed25519, expires 2 years
- **Encryption Subkey**: Curve25519, expires 2 years
- **Authentication Subkey**: Ed25519, expires 2 years

**SSH Keys** (FIDO2):
- **Type**: ed25519-sk (ECDSA over secp256k1)
- **Storage**: Resident key on YubiKey
- **Verification**: PIN required for each use

### YubiKey Configuration

**PIN Settings**:
- User PIN: 6-8 digits, default 123456 (changed by script)
- Admin PIN: 8 digits, default 12345678 (changed by script)
- PIN retry counter: 5 attempts

**Touch Policies**:
- Signing operations: Touch required
- Encryption operations: Touch required
- Authentication operations: Touch required

### Backup Structure

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

---

## Security Considerations

### Threat Model

**Protected Against**:
- Remote key theft (keys never leave YubiKey)
- Silent key usage (touch requirement prevents malware abuse)
- Brute-force attacks (PIN retry limits)
- Physical theft with limited impact (PIN protection)

**Not Protected Against**:
- Shoulder surfing during PIN entry
- Compromised host system during initial key generation
- Physical access to backup files
- Coerced PIN disclosure

### Best Practices Implementation

**During Development**:
1. Never commit test keys or PINs to version control
2. Use separate test YubiKeys, never production devices
3. Regularly audit code for credential leakage
4. Review all external dependencies for vulnerabilities

**For Users**:
1. Generate keys on trusted, preferably air-gapped systems
2. Use strong, unique PINs for User and Admin
3. Store backups encrypted on offline, physically secure media
4. Regularly test backup restoration procedures
5. Never use YubiKey on untrusted computers
6. Replace keys if YubiKey is lost or potentially compromised

### Critical Operations Requiring Explicit Consent

The script must warn and require confirmation before:
1. Overwriting existing YubiKey configuration
2. Transferring keys to YubiKey (destructive move)
3. Changing PINs
4. Resetting YubiKey to factory defaults
5. Deleting backup files

---

## Testing Strategy

### Unit Testing

**Test Harness**: BATS (Bash Automated Testing System)

**Coverage Areas**:
- Helper function validation
- Input sanitization
- Error handling paths
- File operation safety
- Command availability checking

### Integration Testing

**Test Scenarios**:
1. **Full Generate Workflow**:
   - Fresh YubiKey initialization
   - Complete key generation and transfer
   - SSH and Git configuration
   - Backup creation and validation

2. **Full Load Workflow**:
   - Key import from backup
   - Secondary YubiKey provisioning
   - Configuration restoration
   - Functionality verification

3. **Edge Cases**:
   - YubiKey disconnection during operation
   - Invalid backup file handling
   - Incorrect PIN retry behavior
   - Conflicting existing configuration

### Manual Testing Checklist

**Pre-release Testing**:
- [ ] Test on freshly formatted YubiKey 5 NFC
- [ ] Verify on Linux (Ubuntu, Fedora, Arch)
- [ ] Verify on macOS (latest and previous version)
- [ ] Test WSL2 compatibility on Windows
- [ ] Confirm SSH authentication to remote server
- [ ] Verify Git commit signing on GitHub/GitLab
- [ ] Test backup restoration to new YubiKey
- [ ] Validate touch requirement enforcement
- [ ] Check PIN blocking and recovery
- [ ] Test with both RSA and Ed25519 keys

---

## Documentation Requirements

### README.md

**Content Sections**:
1. **Introduction**: Purpose and capabilities
2. **Installation**: Dependencies and setup
3. **Quick Start**: Basic usage examples
4. **Detailed Usage**: All command-line options
5. **Modes**: Generate vs. Load workflows
6. **Configuration**: Customization options
7. **Troubleshooting**: Common issues and solutions
8. **Security**: Best practices and threat model
9. **Contributing**: How to contribute to the project
10. **License**: Open source license information

### TROUBLESHOOTING.md

**Categories**:
- **YubiKey Detection Issues**
- **GPG Agent Connection Problems**
- **SSH Authentication Failures**
- **Git Signing Errors**
- **PIN Block and Recovery**
- **Backup and Restore Issues**
- **Platform-Specific Problems**

Each entry should include:
- Symptom description
- Root cause analysis
- Step-by-step solution
- Prevention tips

### SECURITY.md

**Content**:
- Vulnerability reporting process
- Security best practices for users
- Threat model documentation
- Key management recommendations
- Backup security guidelines
- Incident response procedures

---

## Release and Maintenance

### Versioning

**Semantic Versioning**: MAJOR.MINOR.PATCH

- **MAJOR**: Breaking changes to command-line interface or backup format
- **MINOR**: New features (e.g., additional key types, new modes)
- **PATCH**: Bug fixes and documentation updates

### Release Process

1. **Pre-release Checklist**:
   - All tests passing
   - Documentation updated
   - CHANGELOG.md current
   - Security review completed

2. **Release Steps**:
   - Tag version in git
   - Generate release notes
   - Create signed release archive
   - Update repository documentation
   - Announce on relevant channels

3. **Post-release**:
   - Monitor issue reports
   - Collect user feedback
   - Plan next iteration

### Maintenance Plan

**Ongoing Tasks**:
- Monitor YubiKey firmware updates
- Track GPG and OpenSSH version changes
- Update for new YubiKey models
- Respond to security vulnerabilities
- Community support and issue triage

**Quarterly Reviews**:
- Dependency updates
- Security audit
- Documentation refresh
- Performance optimization
- User feedback incorporation

---

## Success Metrics

### Key Performance Indicators

**Functionality**:
- Script completion rate: >95%
- First-time success rate: >90%
- Backup restoration success: >98%

**Usability**:
- Average setup time: <15 minutes (generate mode)
- Average load time: <5 minutes (load mode)
- User satisfaction: >4.5/5

**Security**:
- Zero credential leakage incidents
- Zero key extraction vulnerabilities
- Touch policy enforcement: 100%

**Code Quality**:
- Shellcheck warnings: 0
- Test coverage: >80%
- Code review approval rate: 100%

---

## Future Enhancements

### Planned Features (v2.0)

1. **Multi-YubiKey Support**: Configure multiple YubiKeys simultaneously
2. **Organizational Deployment**: Batch provisioning with pre-configured templates
3. **Web Interface**: GUI for non-technical users
4. **Mobile Integration**: NFC-based mobile authentication setup
5. **Advanced Key Types**: Support for newer algorithms (e.g., Ed448)

### Potential Integrations

- **Password Managers**: 1Password, Bitwarden integration
- **PAM Integration**: System login via YubiKey
- **Disk Encryption**: LUKS integration for full-disk encryption
- **VPN**: OpenVPN/WireGuard authentication
- **Container Security**: Docker Content Trust signing

---

## References and Resources

### Official Documentation

- [YubiKey Manager CLI Documentation](https://docs.yubico.com/ykman/)
- [GnuPG Manual](https://www.gnupg.org/documentation/manuals/gnupg/)
- [OpenSSH FIDO/U2F Keys](https://www.openssh.com/manual.html)
- [Yubico Developer Portal](https://developers.yubico.com/)

### Community Resources

- [drduh/YubiKey-Guide](https://github.com/drduh/YubiKey-Guide)
- [Yubico Forum](https://forum.yubico.com/)
- [r/yubikey](https://reddit.com/r/yubikey)

### Security Standards

- [NIST SP 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html) - Digital Identity Guidelines
- [FIDO2 Specifications](https://fidoalliance.org/specifications/)
- [OpenPGP Standards](https://www.openpgp.org/about/standard/)

---

## Contact and Support

### Project Maintainers

- Primary Maintainer: [Name] <email>
- Security Contact: security@example.com

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Code contributions
- Bug reports
- Feature requests
- Documentation improvements

### License

[Specify License - e.g., MIT, GPL-3.0, Apache 2.0]

---

**Document Version**: 1.0
**Last Updated**: October 23, 2025
**Status**: Draft - Ready for Development
