_Home Lab Infrastructure – AI Agent Integration \& Standards_

***

## Overview

This document describes the standardized approach for integrating, configuring, and developing AI agents and coding assistants for the **home-lab** repository. It covers agent roles, configuration files, best practices, and workflow recommendations based on the repo’s production-grade experimentation patterns.

***

## 🧑‍💻 Agent Types \& Roles

| Agent Name | Role Description | Common Tools/Contexts |
| :-- | :-- | :-- |
| **Cline** | Interactive coding, context-aware completions, VS Code rules | `.clinerules/`, VS Code |
| **Cursor** | IDE assistant, auto-complete, context rules | `.cursor/rules/homelab.mdc`, Cursor IDE |
| **Aider** | CLI pair programming, YAML-based context | `.aider.conf.yml`, terminal |
| **Claude** | Architecture, planning, natural language support | `Claude.md`, Claude AI |
| **Gemini** | Code reviews, advanced optimization, prompt standards | `GEMINI_RULES.md`, Google Gemini |


***

## ⚙️ Configuration Files

**Agent context and behaviors are set by project rules/configs:**


| File/Dir | Agent(s) | Purpose |
| :-- | :-- | :-- |
| `.clinerules/` | Cline | Markdown coding standards |
| `.cursor/rules/homelab.mdc` | Cursor | Contextual rules for IDE |
| `.aider.conf.yml` | Aider | YAML agent configuration |
| `Claude.md` | Claude | Project context/reference |
| `GEMINI_RULES.md` | Gemini | Prompting/conversation rules |

> **Best Practice:** Keep agent config files updated with major workflow, pattern, or version changes.

***

## 🎯 Agent Workflow \& Usage

1. **Choose the correct agent:**
    - **Cline**: VS Code interactive sessions and context-driven completions.
    - **Cursor**: Automated suggestions, code generation, and rule enforcement in Cursor IDE.
    - **Aider**: Terminal-driven pair programming and CLI automation.
    - **Claude**: Natural language documentation, planning, brainstorming.
    - **Gemini**: Reviews, optimization, and Google ecosystem tasks.
2. **Reference proper context:**
    - Pass project goals, infra constraints, version requirements, and architectural patterns directly to agents.
    - When starting, mention the relevant config/rule files for agent context.
3. **Workflow Example:**

```
# Start a coding session (Aider)
aider src/main.py
# Use Cline for VS Code with standardized rules
/newrule (in sidebar)
# Ask Gemini for code review
[paste code & reference GEMINI_RULES.md]
# Use Claude for planning
[reference Claude.md in conversation]
```


***

## 🛡️ Security \& Compliance for Agents

- **Permissive security** is default for home lab experimentation. Production deployment must apply strict standards.
- **Secret management:** Never expose credentials or sensitive configs to agents unless using secure, encrypted storage (ex. Ansible Vault, .env files, cloud KMS).
- **Pre-commit checks** (automatic): `detect-secrets`, `bandit`, etc., run on all agent-generated code.

***

## 🔄 Update Procedure

- Update agent configs after major tooling/version changes.
- Validate compatibility with latest stable tool versions:
    - **Terraform:** 1.13.3
    - **Kubernetes:** 1.34.x
    - **Ansible Core:** 2.19.3
    - **Python:** 3.11+
    - **Docker:** Latest stable

***

## 🤝 Contribution Guidelines

- New agent integrations must:
    - Include config files in root or dedicated folder.
    - Document usage and context setup.
    - Follow established code quality standards and pre-commit checks.
- Contributions using agents should reference relevant files in commit messages.

***

## 📚 Additional Resources

- See [README.md](./README.md) for full project onboarding.
- Tool-specific guides: `.prettierrc`, `.eslintrc.js`, `.tflint.hcl`, `pyproject.toml`, `ansible.cfg`, etc.
- For agent documentation: See official pages of Cline, Cursor, Aider, Claude, Gemini.

***

**_Maintain agent configs for best results. Reference project context for smarter automation. Prioritize code quality, security, and learn as you build!_**
