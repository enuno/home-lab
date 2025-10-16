# GitHub Copilot Configuration Guide

This guide explains how to set up and use GitHub Copilot with the home lab infrastructure project for optimal AI-assisted coding.

## 📋 Table of Contents

- [Overview](#overview)
- [File Structure](#file-structure)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage Guide](#usage-guide)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

GitHub Copilot is configured to provide context-aware code suggestions optimized for:

- **Infrastructure as Code**: Terraform, Ansible, Kubernetes
- **Container Development**: Docker, Docker Compose
- **Scripting**: Python, Bash, JavaScript/TypeScript
- **Configuration**: YAML, JSON, HCL
- **Production Patterns**: HA, load balancing, caching, monitoring
- **Home Lab Optimization**: Resource efficiency, cost awareness

## 📁 File Structure

```
.github/
├── copilot-instructions.md          # Repository-wide Copilot instructions
└── copilot-chat-instructions.md     # Copilot Chat conversation guidelines

.vscode/
└── settings.json                     # VS Code + Copilot settings
```

### File Purposes

| File | Purpose | Scope |
|------|---------|-------|
| `copilot-instructions.md` | Code generation rules and patterns | All Copilot completions |
| `copilot-chat-instructions.md` | Chat interaction guidelines | Copilot Chat conversations |
| `.vscode/settings.json` | IDE and language-specific settings | VS Code workspace |

## 🚀 Installation

### Prerequisites

1. **GitHub Copilot Subscription**
   - Personal account: [GitHub Copilot Individual](https://github.com/features/copilot)
   - Organization: [GitHub Copilot Business](https://github.com/features/copilot)

2. **VS Code** (recommended) or compatible IDE
   - [Download VS Code](https://code.visualstudio.com/)

### Install Copilot Extensions

```bash
# Install via VS Code command palette (Cmd/Ctrl + Shift + P)
# Search for: "Extensions: Install Extension"

# Or install via command line:
code --install-extension GitHub.copilot
code --install-extension GitHub.copilot-chat
```

### Verify Installation

1. Open VS Code
2. Look for Copilot icon in status bar (bottom right)
3. Should show: ✓ Ready
4. Open any code file - you should see inline suggestions

## ⚙️ Configuration

### 1. Copy Configuration Files

```bash
# Ensure .github directory exists
mkdir -p .github

# Copy Copilot instruction files
cp copilot-instructions.md .github/
cp copilot-chat-instructions.md .github/

# Copy VS Code settings
mkdir -p .vscode
cp settings.json .vscode/
```

### 2. Activate Copilot

```bash
# In VS Code, press Cmd/Ctrl + Shift + P
# Type: "GitHub Copilot: Sign In"
# Follow authentication prompts
```

### 3. Verify Configuration

1. Open any `.tf`, `.yml`, or `.py` file
2. Start typing - you should see suggestions
3. Press `Tab` to accept suggestions
4. Press `Esc` to dismiss suggestions

### 4. Enable Copilot Chat

1. Click Copilot icon in activity bar (left sidebar)
2. Or press `Ctrl + Cmd + I` (Mac) / `Ctrl + Alt + I` (Windows/Linux)
3. Chat panel should open

## 📖 Usage Guide

### Code Completions

#### Basic Usage

```python
# Start typing a function, Copilot suggests completion:
def deploy_infrastructure(
    # Copilot will suggest parameters, types, docstring
```

**Pro Tip**: Write descriptive comments before code blocks:

```python
# Deploy a highly available PostgreSQL cluster using Patroni
# Include automatic failover and HAProxy load balancing
def deploy_postgres_cluster():
    # Copilot will generate production-grade implementation
```

#### Multi-Line Suggestions

Press `Alt + ]` (or `Option + ]` on Mac) to cycle through alternative suggestions.

```terraform
# Copilot offers multiple completion options:
resource "aws_instance" "web" {
  # Press Alt+] to see alternatives:
  # Option 1: Basic configuration
  # Option 2: HA configuration
  # Option 3: Auto-scaling configuration
```

### Copilot Chat

#### Open Chat

- **Keyboard**: `Ctrl + Cmd + I` (Mac) / `Ctrl + Alt + I` (Windows/Linux)
- **Menu**: View → Command Palette → "GitHub Copilot: Open Chat"
- **Icon**: Click Copilot icon in activity bar

#### Chat Commands

```plaintext
/explain - Explain selected code
/fix - Suggest fixes for problems
/tests - Generate tests
/doc - Generate documentation
/help - Show help
```

#### Example Conversations

**Architecture Planning**:
```
You: "I need to design a HA PostgreSQL cluster for my home lab.
     I have 3 VMs with 4GB RAM each."

Copilot: [Provides architecture diagram, component list,
          implementation steps with Terraform + Ansible]
```

**Code Review**:
```
You: "Review this Ansible playbook for best practices"
[Select code]

Copilot: [Analyzes code, provides structured feedback with
          ✅ strengths, ⚠️ improvements, 🔴 critical issues]
```

**Debugging**:
```
You: "My Kubernetes pod keeps crashing with exit code 137"

Copilot: [Diagnoses OOM issue, suggests resource limits,
          provides fixed manifest]
```

### Inline Chat

1. Select code
2. Press `Cmd + I` (Mac) / `Ctrl + I` (Windows/Linux)
3. Type your instruction
4. Copilot modifies code in place

**Example**:
```python
# Select this function
def backup_database(host, port):
    pass

# Inline chat: "Add error handling, logging, and retry logic"
# Copilot updates the function with improvements
```

### Smart Actions

Right-click on code and select:
- **Copilot** → Explain This
- **Copilot** → Fix This
- **Copilot** → Generate Tests
- **Copilot** → Generate Docs

## 💡 Best Practices

### Writing Effective Prompts

#### ✅ Good Prompts (Specific and Contextual)

```python
# Create a Terraform module for a highly available PostgreSQL database
# Requirements:
# - Multi-AZ deployment in AWS
# - Automatic failover with RDS
# - Read replicas for scaling
# - Backup retention: 7 days
# - Monitoring with CloudWatch alarms
```

```yaml
# Ansible playbook to configure nginx as a reverse proxy
# Features:
# - SSL termination with Let's Encrypt
# - Rate limiting: 100 req/10s per IP
# - Health checks for backend servers
# - Access logging to /var/log/nginx
```

#### ❌ Vague Prompts (Too General)

```python
# Make a database
# Create a web server
# Set up monitoring
```

### Leveraging Context

Copilot uses context from:
1. **Current file**: Code you're writing
2. **Open tabs**: Related files you have open
3. **Project files**: Other files in workspace
4. **Instructions**: `.github/copilot-instructions.md`

**Maximize context**:
- Open related files in tabs
- Keep `.github/copilot-instructions.md` in sync
- Use descriptive variable/function names
- Write detailed comments

### Code Review Workflow

1. **Generate code** with Copilot
2. **Review suggestions** - don't blindly accept
3. **Test code** - verify it works
4. **Refactor** - optimize for your use case
5. **Document** - add comments for future you

### Language-Specific Tips

#### Terraform

```hcl
# Comment describing resource purpose
# Copilot generates with best practices:
# - Version constraints
# - for_each instead of count
# - Proper tags
# - Lifecycle rules
resource "aws_instance" "web" {
  # Copilot completes...
}
```

#### Ansible

```yaml
---
# Playbook: Configure web servers with nginx and SSL
# Features: Auto-renewal, rate limiting, monitoring
# Copilot generates:
# - FQCN module names
# - Error handling blocks
# - Idempotent tasks
# - Proper handlers
- name: Configure web servers
  # Copilot completes...
```

#### Python

```python
"""Module for infrastructure deployment automation.

This module provides functions for deploying and managing
infrastructure resources with error handling, logging,
and monitoring integration.
"""

# Copilot uses docstring for context and generates:
# - Type hints
# - Error handling
# - Logging
# - Comprehensive docstrings

def deploy_service(
    # Copilot suggests parameters and types
```

### Security Considerations

⚠️ **Always Review Generated Code**:

- **Secrets**: Never commit generated code with hardcoded secrets
- **Permissions**: Verify least-privilege access
- **Validation**: Check input validation and sanitization
- **Error Handling**: Ensure errors don't leak sensitive info

**Good Practice**:
```python
# Copilot might suggest:
api_key = "sk-1234567890"  # ❌ DON'T USE

# Always use environment variables:
api_key = os.getenv("API_KEY")  # ✅ CORRECT
if not api_key:
    raise ValueError("API_KEY not set")
```

## 🔧 Customization

### Project-Specific Instructions

Edit `.github/copilot-instructions.md` to add:

```markdown
## Project-Specific Patterns

### Authentication
All services must use OAuth2 with our internal IdP:
- Provider: Keycloak
- Realm: homelab
- Client ID: from environment variable
```

### Language-Specific Rules

Edit `.vscode/settings.json`:

```json
{
  "github.copilot.chat.codeGeneration.instructions": [
    {
      "text": "Always use asyncio for Python I/O operations"
    },
    {
      "text": "Prefer functional components in React"
    }
  ]
}
```

### Disable for Sensitive Files

Add to `.vscode/settings.json`:

```json
{
  "github.copilot.enable": {
    "*": true,
    "plaintext": false,
    "secrets.yml": false,
    "credentials.json": false
  }
}
```

## 🐛 Troubleshooting

### Copilot Not Showing Suggestions

**Check**:
1. Status bar icon shows ✓ (not ⚠️ or ×)
2. File type is enabled in settings
3. You're signed in: `Cmd+Shift+P` → "GitHub Copilot: Sign In"
4. Extension is activated: `Cmd+Shift+P` → "GitHub Copilot: Status"

**Fix**:
```bash
# Reload window
Cmd+Shift+P → "Developer: Reload Window"

# Reinstall extension
code --uninstall-extension GitHub.copilot
code --install-extension GitHub.copilot
```

### Suggestions Are Low Quality

**Improve by**:
1. Adding more context in comments
2. Opening related files
3. Using descriptive names
4. Updating `.github/copilot-instructions.md`

**Example**:

```python
# ❌ Low quality - vague
def process():
    pass

# ✅ High quality - specific
def process_terraform_state_file(
    state_file_path: Path,
    backup_dir: Path,
    validate_checksums: bool = True
) -> Dict[str, Any]:
    """Process Terraform state file with validation.

    Args:
        state_file_path: Path to .tfstate file
        backup_dir: Directory for state backups
        validate_checksums: Whether to validate file checksums

    Returns:
        Dictionary with processing results

    Raises:
        ValueError: If state file is invalid
        IOError: If file operations fail
    """
    # Copilot generates much better code now
```

### Chat Not Responding

**Try**:
1. Check internet connection
2. Clear chat history: Click trash icon in chat panel
3. Restart VS Code
4. Check GitHub status: https://www.githubstatus.com/

### Wrong Context Being Used

**Solution**:
1. Close unrelated tabs
2. Update `.github/copilot-instructions.md`
3. Be more specific in prompts
4. Use inline chat for targeted changes

## 📊 Productivity Tips

### Keyboard Shortcuts

| Action | Mac | Windows/Linux |
|--------|-----|---------------|
| Accept suggestion | `Tab` | `Tab` |
| Dismiss suggestion | `Esc` | `Esc` |
| Next suggestion | `Option + ]` | `Alt + ]` |
| Previous suggestion | `Option + [` | `Alt + [` |
| Open chat | `Cmd + Shift + I` | `Ctrl + Alt + I` |
| Inline chat | `Cmd + I` | `Ctrl + I` |
| Open Copilot | `Ctrl + Shift + Space` | `Ctrl + Shift + Space` |

### Workflow Integration

#### Morning Review
```bash
# Start day with Copilot chat:
"Review yesterday's commits and suggest priorities for today"
```

#### Code Review
```bash
# Before commit:
1. Select all changed code
2. Right-click → Copilot → Explain This
3. Review explanation
4. Ask chat: "Any security concerns with these changes?"
```

#### Documentation
```bash
# Generate documentation:
1. Select function/class
2. Inline chat: "Generate comprehensive docstring"
3. Review and refine
```

#### Testing
```bash
# Generate tests:
1. Select function
2. Right-click → Copilot → Generate Tests
3. Review test coverage
4. Add edge cases manually
```

## 🎓 Learning Resources

### Official Documentation
- [GitHub Copilot Docs](https://docs.github.com/en/copilot)
- [VS Code Copilot Extension](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)
- [Copilot Best Practices](https://github.blog/2023-06-20-how-to-write-better-prompts-for-github-copilot/)

### Video Tutorials
- [GitHub Copilot Quickstart](https://www.youtube.com/watch?v=dhfTaSGYQ4o)
- [Advanced Copilot Tips](https://www.youtube.com/watch?v=hPVatUSvZq0)

### Community
- [GitHub Community Forum](https://github.community/t/copilot)
- [VS Code Discord](https://discord.gg/vscode)

## 🆘 Getting Help

### Internal Resources
1. Review `.github/copilot-instructions.md`
2. Check `.github/copilot-chat-instructions.md`
3. Review `README-VIBE-CODING-SETUP.md`

### External Support
1. [GitHub Support](https://support.github.com/)
2. [VS Code Issues](https://github.com/microsoft/vscode/issues)
3. [Copilot Issues](https://github.com/github/copilot-docs/issues)

## 📝 Feedback & Improvement

### Provide Feedback

**Good suggestions**:
- Thumbs up in suggestion tooltip
- Share patterns that work well

**Bad suggestions**:
- Thumbs down in suggestion tooltip
- Report issues to GitHub

### Update Instructions

As your project evolves, update:
1. `.github/copilot-instructions.md` - Add new patterns
2. `.github/copilot-chat-instructions.md` - Refine responses
3. `.vscode/settings.json` - Adjust language settings

---

**Remember**: Copilot is a tool to augment your expertise, not replace it. Always review, test, and understand generated code before using it in production.
