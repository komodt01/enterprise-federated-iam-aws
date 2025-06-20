# terraform/variables.tf
# Variable definitions for Enterprise Federated IAM project

# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================

variable "project_name" {
  description = "Name of the project for resource naming and tagging"
  type        = string
  default     = "enterprise-federated-iam"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "Primary AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "enterprise-federated-iam"
    ManagedBy   = "terraform"
    Environment = "dev"
  }
}

# ============================================================================
# IDENTITY CENTER CONFIGURATION (Limited Terraform Support)
# ============================================================================

variable "identity_center_instance_arn" {
  description = "ARN of the Identity Center instance (must be created manually first)"
  type        = string
  default     = ""
  # Note: This must be obtained after manual Identity Center setup
}

variable "saml_provider_name" {
  description = "Name for the SAML identity provider"
  type        = string
  default     = "CompanyIdP"
}

variable "saml_metadata_url" {
  description = "URL to SAML IdP metadata (for external IdPs like Okta/SSOCircle)"
  type        = string
  default     = ""
  # Note: This will be provided by your external SAML IdP
}

# ============================================================================
# MULTI-ACCOUNT SETUP
# ============================================================================

variable "identity_account_id" {
  description = "AWS Account ID where Identity Center is deployed"
  type        = string
  # Example: "123456789012"
}

variable "workload_accounts" {
  description = "Map of workload accounts where cross-account roles will be created"
  type = map(object({
    account_id  = string
    description = string
    ou_path     = string
  }))
  default = {
    dev = {
      account_id  = "123456789013"
      description = "Development workload account"
      ou_path     = "Development"
    }
    staging = {
      account_id  = "123456789014"
      description = "Staging workload account"
      ou_path     = "Non-Production"
    }
    prod = {
      account_id  = "123456789015"
      description = "Production workload account"
      ou_path     = "Production"
    }
  }
}

variable "logging_account_id" {
  description = "AWS Account ID for centralized logging (CloudTrail)"
  type        = string
  default     = ""
  # If empty, will use identity_account_id
}

# ============================================================================
# IAM ROLE CONFIGURATION
# ============================================================================

variable "permission_sets" {
  description = "Permission sets to create in Identity Center"
  type = map(object({
    description           = string
    session_duration     = string
    managed_policies     = list(string)
    inline_policy        = string
    customer_managed_policies = list(string)
    tags                 = map(string)
  }))
  default = {
    "DeveloperAccess" = {
      description           = "Developer access with limited permissions"
      session_duration     = "PT8H"  # 8 hours
      managed_policies     = [
        "arn:aws:iam::aws:policy/PowerUserAccess"
      ]
      inline_policy        = ""
      customer_managed_policies = []
      tags = {
        AccessLevel = "Developer"
        Department  = "Engineering"
      }
    }
    "ArchitectAccess" = {
      description           = "Architect access with broader permissions"
      session_duration     = "PT12H"  # 12 hours
      managed_policies     = [
        "arn:aws:iam::aws:policy/job-function/SystemAdministrator"
      ]
      inline_policy        = ""
      customer_managed_policies = []
      tags = {
        AccessLevel = "Architect"
        Department  = "Engineering"
      }
    }
    "SecurityAuditorAccess" = {
      description           = "Read-only access for security auditing"
      session_duration     = "PT4H"  # 4 hours
      managed_policies     = [
        "arn:aws:iam::aws:policy/SecurityAudit",
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
      ]
      inline_policy        = ""
      customer_managed_policies = []
      tags = {
        AccessLevel = "Auditor"
        Department  = "Security"
      }
    }
  }
}

variable "cross_account_roles" {
  description = "Cross-account roles to create in workload accounts"
  type = map(object({
    description                = string
    max_session_duration      = number
    permissions_boundary_arn  = string
    trusted_entities         = list(string)
    condition_keys           = map(any)
  }))
  default = {
    "FederatedDeveloperRole" = {
      description               = "Cross-account role for federated developers"
      max_session_duration     = 28800  # 8 hours
      permissions_boundary_arn = ""
      trusted_entities         = ["arn:aws:iam::IDENTITY-ACCOUNT:root"]
      condition_keys = {
        "StringEquals" = {
          "saml:aud" = "https://signin.aws.amazon.com/saml"
        }
        "StringLike" = {
          "saml:sub" = "*@company.com"
        }
      }
    }
    "FederatedArchitectRole" = {
      description               = "Cross-account role for federated architects"
      max_session_duration     = 43200  # 12 hours
      permissions_boundary_arn = ""
      trusted_entities         = ["arn:aws:iam::IDENTITY-ACCOUNT:root"]
      condition_keys = {
        "StringEquals" = {
          "saml:aud" = "https://signin.aws.amazon.com/saml"
        }
        "StringLike" = {
          "saml:sub" = "*@company.com"
        }
      }
    }
  }
}

# ============================================================================
# CLOUDTRAIL AND LOGGING
# ============================================================================

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging"
  type        = bool
  default     = true
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs (must be globally unique)"
  type        = string
  default     = ""
  # If empty, will auto-generate: "${var.project_name}-cloudtrail-${random_id}"
}

variable "cloudtrail_retention_days" {
  description = "Number of days to retain CloudTrail logs"
  type        = number
  default     = 90
}

variable "enable_cloudtrail_insights" {
  description = "Enable CloudTrail Insights for anomaly detection"
  type        = bool
  default     = false  # Additional cost
}

variable "log_group_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 14
}

# ============================================================================
# SECURITY CONFIGURATION
# ============================================================================

variable "require_mfa" {
  description = "Require MFA for all federated access"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "CIDR blocks allowed for federated access (empty = allow all)"
  type        = list(string)
  default     = []
  # Example: ["203.0.113.0/24", "198.51.100.0/24"]
}

variable "session_timeout_hours" {
  description = "Maximum session timeout in hours"
  type        = number
  default     = 8
  
  validation {
    condition     = var.session_timeout_hours >= 1 && var.session_timeout_hours <= 12
    error_message = "Session timeout must be between 1 and 12 hours."
  }
}

variable "enable_session_policies" {
  description = "Enable additional session policies for enhanced security"
  type        = bool
  default     = true
}

# ============================================================================
# SAML ATTRIBUTE MAPPING
# ============================================================================

variable "saml_attribute_map" {
  description = "Mapping of SAML attributes to AWS session tags"
  type = map(string)
  default = {
    "https://aws.amazon.com/SAML/Attributes/RoleSessionName" = "sub"
    "https://aws.amazon.com/SAML/Attributes/SessionDuration" = "SessionDuration"
    "Department"                                             = "Department"
    "CostCenter"                                            = "CostCenter"
    "Project"                                               = "Project"
  }
}

# ============================================================================
# COMPLIANCE AND MONITORING
# ============================================================================

variable "enable_config" {
  description = "Enable AWS Config for compliance monitoring"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty for threat detection"
  type        = bool
  default     = false  # Can be expensive in multi-account setup
}

variable "notification_email" {
  description = "Email address for security notifications"
  type        = string
  default     = ""
}

variable "enable_access_analyzer" {
  description = "Enable IAM Access Analyzer"
  type        = bool
  default     = true
}

# ============================================================================
# TERRAFORM BACKEND CONFIGURATION
# ============================================================================

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state (if using remote backend)"
  type        = string
  default     = ""
}

variable "terraform_state_key" {
  description = "S3 key for Terraform state file"
  type        = string
  default     = "enterprise-iam/terraform.tfstate"
}

variable "terraform_dynamodb_table" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
  default     = ""
}