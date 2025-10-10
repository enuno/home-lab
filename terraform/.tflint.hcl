# TFLint Configuration for Home Lab Infrastructure
# https://github.com/terraform-linters/tflint

config {
  # Plugin directory
  plugin_dir = "~/.tflint.d/plugins"

  # Module inspection
  module = true

  # Force provider installation
  force = false

  # Disable color output
  disabled_by_default = false
}

# AWS Plugin
plugin "aws" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"

  # Deep check for AWS resources
  deep_check = true
}

# Google Cloud Plugin
plugin "google" {
  enabled = true
  version = "0.28.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"

  # Deep check for GCP resources
  deep_check = true
}

# Azure Plugin
plugin "azurerm" {
  enabled = true
  version = "0.25.1"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"

  # Deep check for Azure resources
  deep_check = true
}

# Terraform Core Rules
# https://github.com/terraform-linters/tflint-ruleset-terraform

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
  style   = "semver" # Options: "flexible", "semver"
}

rule "terraform_naming_convention" {
  enabled = true

  # Variable naming
  variable {
    format = "snake_case"
  }

  # Local value naming
  locals {
    format = "snake_case"
  }

  # Output naming
  output {
    format = "snake_case"
  }

  # Resource naming
  resource {
    format = "snake_case"
  }

  # Data source naming
  data {
    format = "snake_case"
  }

  # Module naming
  module {
    format = "snake_case"
  }
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}

# Best Practices
rule "terraform_unused_required_providers" {
  enabled = true
}

# Discourage legacy patterns
rule "terraform_module_version" {
  enabled = true
}

# AWS-Specific Rules (examples)
rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

rule "aws_elasticache_cluster_invalid_type" {
  enabled = true
}

rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = false # Disabled for home lab
}

rule "aws_iam_role_policy_too_long_policy" {
  enabled = true
}

rule "aws_iam_policy_too_long_policy" {
  enabled = true
}

rule "aws_s3_bucket_invalid_acl" {
  enabled = true
}

rule "aws_resource_missing_tags" {
  enabled = true
  tags = [
    "Environment",
    "ManagedBy",
    "Project"
  ]
  exclude = [
    # Exclude resources that don't support tags
    "aws_iam_*",
    "aws_vpc_endpoint_route_table_association",
    "aws_route_table_association"
  ]
}

# Google Cloud-Specific Rules
rule "google_project_iam_member_invalid_member" {
  enabled = true
}

rule "google_resource_missing_labels" {
  enabled = true
  labels = [
    "environment",
    "managed-by",
    "project"
  ]
}

# Security Rules
rule "aws_security_group_rule_inline_rule" {
  enabled = true
}

rule "aws_db_instance_default_parameter_group" {
  enabled = true
}

rule "aws_elasticache_cluster_default_parameter_group" {
  enabled = true
}

# Performance and Cost Optimization
rule "aws_instance_previous_type" {
  enabled = true
}

rule "aws_db_instance_previous_type" {
  enabled = true
}

# Home Lab Specific Overrides

# Relaxed rules for experimentation
rule "terraform_empty_list_equality" {
  enabled = false # Allow for flexibility in conditionals
}

# Warnings instead of errors for some rules (home lab context)
rule "aws_resource_missing_tags" {
  enabled = true
  severity = "warning" # Warning instead of error
}

rule "google_resource_missing_labels" {
  enabled = true
  severity = "warning"
}
