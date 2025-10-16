# Makefile for Home Lab Infrastructure
# Common tasks automation for Terraform, Ansible, Kubernetes, Docker

.PHONY: help
.DEFAULT_GOAL := help

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Project variables
PROJECT_NAME ?= homelab
ENVIRONMENT ?= dev
TERRAFORM_DIR ?= terraform
ANSIBLE_DIR ?= ansible
K8S_DIR ?= kubernetes
DOCKER_DIR ?= docker

# Tool versions
TERRAFORM_VERSION := 1.13.3
ANSIBLE_VERSION := 2.19.3
KUBECTL_VERSION := 1.34.0

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\n${BLUE}Usage:${NC}\n  make ${GREEN}<target>${NC}\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  ${GREEN}%-20s${NC} %s\n", $$1, $$2 } /^##@/ { printf "\n${YELLOW}%s${NC}\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

version: ## Show tool versions
	@echo "${BLUE}Tool Versions:${NC}"
	@echo "Terraform: $(shell terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo 'not installed')"
	@echo "Ansible:   $(shell ansible --version 2>/dev/null | head -n1 || echo 'not installed')"
	@echo "kubectl:   $(shell kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' || echo 'not installed')"
	@echo "Docker:    $(shell docker version --format '{{.Client.Version}}' 2>/dev/null || echo 'not installed')"
	@echo "Python:    $(shell python3 --version 2>/dev/null || echo 'not installed')"

check-tools: ## Check if required tools are installed
	@echo "${BLUE}Checking required tools...${NC}"
	@command -v terraform >/dev/null 2>&1 || { echo "${RED}terraform not found${NC}"; exit 1; }
	@command -v ansible >/dev/null 2>&1 || { echo "${RED}ansible not found${NC}"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "${RED}kubectl not found${NC}"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "${RED}docker not found${NC}"; exit 1; }
	@echo "${GREEN}All required tools are installed${NC}"

##@ Setup

install-tools: ## Install/update development tools
	@echo "${BLUE}Installing development tools...${NC}"
	pip install --upgrade pip
	pip install ansible==${ANSIBLE_VERSION} ansible-lint yamllint
	pip install pre-commit black ruff mypy pytest
	pre-commit install
	@echo "${GREEN}Tools installed successfully${NC}"

setup: install-tools ## Initial project setup
	@echo "${BLUE}Setting up project...${NC}"
	@mkdir -p ${TERRAFORM_DIR}/{modules,environments}
	@mkdir -p ${ANSIBLE_DIR}/{playbooks,roles,inventory}
	@mkdir -p ${K8S_DIR}/{base,overlays}
	@mkdir -p ${DOCKER_DIR}
	@mkdir -p logs backups
	@echo "${GREEN}Project setup complete${NC}"

##@ Linting & Formatting

lint: lint-terraform lint-ansible lint-k8s lint-docker lint-python lint-yaml ## Run all linters
	@echo "${GREEN}All linting checks passed${NC}"

lint-terraform: ## Lint Terraform code
	@echo "${BLUE}Linting Terraform...${NC}"
	@cd ${TERRAFORM_DIR} && terraform fmt -check -recursive || { echo "${RED}Terraform formatting issues found${NC}"; exit 1; }
	@tflint --config=.tflint.hcl ${TERRAFORM_DIR} || { echo "${RED}TFLint issues found${NC}"; exit 1; }
	@echo "${GREEN}Terraform linting passed${NC}"

lint-ansible: ## Lint Ansible code
	@echo "${BLUE}Linting Ansible...${NC}"
	@ansible-lint ${ANSIBLE_DIR} || { echo "${RED}Ansible lint issues found${NC}"; exit 1; }
	@echo "${GREEN}Ansible linting passed${NC}"

lint-k8s: ## Lint Kubernetes manifests
	@echo "${BLUE}Linting Kubernetes manifests...${NC}"
	@find ${K8S_DIR} -name "*.yaml" -o -name "*.yml" | xargs yamllint || { echo "${RED}YAML lint issues found${NC}"; exit 1; }
	@echo "${GREEN}Kubernetes linting passed${NC}"

lint-docker: ## Lint Dockerfiles
	@echo "${BLUE}Linting Dockerfiles...${NC}"
	@find . -name "Dockerfile*" | xargs hadolint || { echo "${RED}Dockerfile lint issues found${NC}"; exit 1; }
	@echo "${GREEN}Dockerfile linting passed${NC}"

lint-python: ## Lint Python code
	@echo "${BLUE}Linting Python...${NC}"
	@ruff check . || { echo "${RED}Ruff issues found${NC}"; exit 1; }
	@black --check . || { echo "${RED}Black formatting issues found${NC}"; exit 1; }
	@mypy . || { echo "${YELLOW}MyPy warnings found${NC}"; }
	@echo "${GREEN}Python linting passed${NC}"

lint-yaml: ## Lint all YAML files
	@echo "${BLUE}Linting YAML files...${NC}"
	@yamllint -c .yamllint . || { echo "${RED}YAML lint issues found${NC}"; exit 1; }
	@echo "${GREEN}YAML linting passed${NC}"

format: format-terraform format-python ## Auto-format all code
	@echo "${GREEN}All code formatted${NC}"

format-terraform: ## Format Terraform code
	@echo "${BLUE}Formatting Terraform...${NC}"
	@cd ${TERRAFORM_DIR} && terraform fmt -recursive
	@echo "${GREEN}Terraform formatted${NC}"

format-python: ## Format Python code
	@echo "${BLUE}Formatting Python...${NC}"
	@black .
	@ruff check --fix .
	@echo "${GREEN}Python formatted${NC}"

##@ Terraform

tf-init: ## Initialize Terraform
	@echo "${BLUE}Initializing Terraform...${NC}"
	@cd ${TERRAFORM_DIR}/environments/${ENVIRONMENT} && terraform init
	@echo "${GREEN}Terraform initialized${NC}"

tf-plan: ## Run Terraform plan
	@echo "${BLUE}Running Terraform plan...${NC}"
	@cd ${TERRAFORM_DIR}/environments/${ENVIRONMENT} && terraform plan -out=tfplan
	@echo "${GREEN}Terraform plan complete${NC}"

tf-apply: ## Apply Terraform changes
	@echo "${BLUE}Applying Terraform changes...${NC}"
	@cd ${TERRAFORM_DIR}/environments/${ENVIRONMENT} && terraform apply tfplan
	@echo "${GREEN}Terraform applied${NC}"

tf-destroy: ## Destroy Terraform infrastructure
	@echo "${RED}Destroying Terraform infrastructure...${NC}"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd ${TERRAFORM_DIR}/environments/${ENVIRONMENT} && terraform destroy; \
	fi

tf-validate: ## Validate Terraform configuration
	@echo "${BLUE}Validating Terraform...${NC}"
	@cd ${TERRAFORM_DIR}/environments/${ENVIRONMENT} && terraform validate
	@echo "${GREEN}Terraform validation passed${NC}"

tf-docs: ## Generate Terraform documentation
	@echo "${BLUE}Generating Terraform documentation...${NC}"
	@terraform-docs markdown table --output-file README.md ${TERRAFORM_DIR}
	@echo "${GREEN}Terraform documentation generated${NC}"

##@ Ansible

ansible-ping: ## Ping all Ansible hosts
	@echo "${BLUE}Pinging Ansible hosts...${NC}"
	@cd ${ANSIBLE_DIR} && ansible all -m ping -i inventory/${ENVIRONMENT}/hosts

ansible-check: ## Run Ansible playbook in check mode
	@echo "${BLUE}Running Ansible check...${NC}"
	@cd ${ANSIBLE_DIR} && ansible-playbook -i inventory/${ENVIRONMENT}/hosts playbooks/site.yml --check

ansible-run: ## Run Ansible playbook
	@echo "${BLUE}Running Ansible playbook...${NC}"
	@cd ${ANSIBLE_DIR} && ansible-playbook -i inventory/${ENVIRONMENT}/hosts playbooks/site.yml

ansible-syntax: ## Check Ansible syntax
	@echo "${BLUE}Checking Ansible syntax...${NC}"
	@cd ${ANSIBLE_DIR} && ansible-playbook playbooks/site.yml --syntax-check

ansible-facts: ## Gather Ansible facts
	@echo "${BLUE}Gathering Ansible facts...${NC}"
	@cd ${ANSIBLE_DIR} && ansible all -m setup -i inventory/${ENVIRONMENT}/hosts

##@ Kubernetes

k8s-apply: ## Apply Kubernetes manifests
	@echo "${BLUE}Applying Kubernetes manifests...${NC}"
	@kubectl apply -k ${K8S_DIR}/overlays/${ENVIRONMENT}
	@echo "${GREEN}Kubernetes manifests applied${NC}"

k8s-delete: ## Delete Kubernetes resources
	@echo "${BLUE}Deleting Kubernetes resources...${NC}"
	@kubectl delete -k ${K8S_DIR}/overlays/${ENVIRONMENT}
	@echo "${GREEN}Kubernetes resources deleted${NC}"

k8s-diff: ## Show Kubernetes diff
	@echo "${BLUE}Showing Kubernetes diff...${NC}"
	@kubectl diff -k ${K8S_DIR}/overlays/${ENVIRONMENT}

k8s-validate: ## Validate Kubernetes manifests
	@echo "${BLUE}Validating Kubernetes manifests...${NC}"
	@kubectl apply -k ${K8S_DIR}/overlays/${ENVIRONMENT} --dry-run=client
	@echo "${GREEN}Kubernetes manifests validated${NC}"

k8s-status: ## Show Kubernetes cluster status
	@echo "${BLUE}Kubernetes Cluster Status:${NC}"
	@kubectl get nodes
	@kubectl get pods -A
	@kubectl top nodes

##@ Docker

docker-build: ## Build Docker image
	@echo "${BLUE}Building Docker image...${NC}"
	@docker build -t ${PROJECT_NAME}:latest ${DOCKER_DIR}
	@echo "${GREEN}Docker image built${NC}"

docker-push: ## Push Docker image
	@echo "${BLUE}Pushing Docker image...${NC}"
	@docker push ${PROJECT_NAME}:latest
	@echo "${GREEN}Docker image pushed${NC}"

docker-compose-up: ## Start Docker Compose services
	@echo "${BLUE}Starting Docker Compose services...${NC}"
	@docker-compose -f ${DOCKER_DIR}/docker-compose.yml up -d
	@echo "${GREEN}Services started${NC}"

docker-compose-down: ## Stop Docker Compose services
	@echo "${BLUE}Stopping Docker Compose services...${NC}"
	@docker-compose -f ${DOCKER_DIR}/docker-compose.yml down
	@echo "${GREEN}Services stopped${NC}"

docker-clean: ## Clean Docker resources
	@echo "${BLUE}Cleaning Docker resources...${NC}"
	@docker system prune -af --volumes
	@echo "${GREEN}Docker resources cleaned${NC}"

##@ Testing

test: test-python test-ansible ## Run all tests
	@echo "${GREEN}All tests passed${NC}"

test-python: ## Run Python tests
	@echo "${BLUE}Running Python tests...${NC}"
	@pytest tests/ -v --cov=. --cov-report=html
	@echo "${GREEN}Python tests passed${NC}"

test-ansible: ## Run Ansible tests with Molecule
	@echo "${BLUE}Running Ansible tests...${NC}"
	@cd ${ANSIBLE_DIR} && molecule test
	@echo "${GREEN}Ansible tests passed${NC}"

##@ Security

security-scan: ## Run security scans
	@echo "${BLUE}Running security scans...${NC}"
	@trivy fs --severity HIGH,CRITICAL .
	@bandit -r . -f json -o bandit-report.json
	@echo "${GREEN}Security scan complete${NC}"

secrets-scan: ## Scan for secrets
	@echo "${BLUE}Scanning for secrets...${NC}"
	@detect-secrets scan --baseline .secrets.baseline
	@echo "${GREEN}Secrets scan complete${NC}"

##@ Backup & Restore

backup: ## Backup important data
	@echo "${BLUE}Creating backup...${NC}"
	@mkdir -p backups
	@tar -czf backups/backup-$(shell date +%Y%m%d-%H%M%S).tar.gz \
		--exclude='*.tfstate' \
		--exclude='node_modules' \
		--exclude='.terraform' \
		${TERRAFORM_DIR} ${ANSIBLE_DIR} ${K8S_DIR}
	@echo "${GREEN}Backup created in backups/${NC}"

restore: ## Restore from backup (use BACKUP_FILE=filename)
	@echo "${BLUE}Restoring from backup...${NC}"
	@tar -xzf ${BACKUP_FILE}
	@echo "${GREEN}Restore complete${NC}"

##@ Cleanup

clean: clean-terraform clean-python clean-logs ## Clean all generated files
	@echo "${GREEN}Cleanup complete${NC}"

clean-terraform: ## Clean Terraform files
	@echo "${BLUE}Cleaning Terraform files...${NC}"
	@find ${TERRAFORM_DIR} -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find ${TERRAFORM_DIR} -name "*.tfstate*" -delete 2>/dev/null || true
	@find ${TERRAFORM_DIR} -name "tfplan" -delete 2>/dev/null || true
	@echo "${GREEN}Terraform files cleaned${NC}"

clean-python: ## Clean Python cache files
	@echo "${BLUE}Cleaning Python files...${NC}"
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type f -name "*.pyo" -delete 2>/dev/null || true
	@find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	@rm -rf .pytest_cache .mypy_cache .coverage htmlcov
	@echo "${GREEN}Python files cleaned${NC}"

clean-logs: ## Clean log files
	@echo "${BLUE}Cleaning log files...${NC}"
	@find . -name "*.log" -delete 2>/dev/null || true
	@rm -rf logs/*.log
	@echo "${GREEN}Log files cleaned${NC}"

##@ Documentation

docs: ## Generate documentation
	@echo "${BLUE}Generating documentation...${NC}"
	@terraform-docs markdown table --output-file README.md ${TERRAFORM_DIR}
	@echo "${GREEN}Documentation generated${NC}"

##@ Development

dev-shell: ## Start development shell
	@echo "${BLUE}Starting development shell...${NC}"
	@docker-compose -f ${DOCKER_DIR}/docker-compose.dev.yml run --rm dev

watch: ## Watch for changes and run tests
	@echo "${BLUE}Watching for changes...${NC}"
	@find . -name "*.py" | entr -c make test-python
