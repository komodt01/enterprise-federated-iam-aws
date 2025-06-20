# terraform/main.tf
# Phase 3: Adding IAM roles with SAML trust policies

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Data source to reference manually created SAML provider
data "aws_iam_saml_provider" "main" {
  arn = "arn:${local.partition}:iam::${local.current_account_id}:saml-provider/${var.saml_provider_name}"
}

# Random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Local values
locals {
  current_account_id = data.aws_caller_identity.current.account_id
  current_region     = data.aws_region.current.name
  partition          = data.aws_partition.current.partition
  
  cloudtrail_bucket_name = var.cloudtrail_bucket_name != "" ? var.cloudtrail_bucket_name : "${var.project_name}-cloudtrail-${random_id.suffix.hex}"
}

# ============================================================================
# PHASE 1: TEST BUCKET (Keep for now)
# ============================================================================

resource "aws_s3_bucket" "test_bucket" {
  bucket = "${var.project_name}-test-${random_id.suffix.hex}"
  
  tags = {
    Name        = "Test Bucket"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================================
# PHASE 2: CLOUDTRAIL LOGGING INFRASTRUCTURE
# ============================================================================

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = local.cloudtrail_bucket_name
  
  tags = merge(var.common_tags, {
    Name    = local.cloudtrail_bucket_name
    Purpose = "CloudTrail Logs"
  })
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:${local.partition}:cloudtrail:${local.current_region}:${local.current_account_id}:trail/${var.project_name}-cloudtrail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:${local.partition}:cloudtrail:${local.current_region}:${local.current_account_id}:trail/${var.project_name}-cloudtrail"
          }
        }
      }
    ]
  })
}

# CloudWatch log group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_cloudtrail ? 1 : 0
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = var.log_group_retention_days
  
  tags = merge(var.common_tags, {
    Name    = "/aws/cloudtrail/${var.project_name}"
    Purpose = "CloudTrail Logs"
  })
}

# IAM role for CloudTrail to write to CloudWatch
resource "aws_iam_role" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  name  = "${var.project_name}-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# IAM policy for CloudTrail
resource "aws_iam_role_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0
  name  = "${var.project_name}-cloudtrail-policy"
  role  = aws_iam_role.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
      }
    ]
  })
}

# CloudTrail itself
resource "aws_cloudtrail" "main" {
  count                          = var.enable_cloudtrail ? 1 : 0
  name                           = "${var.project_name}-cloudtrail"
  s3_bucket_name                 = aws_s3_bucket.cloudtrail[0].bucket
  s3_key_prefix                  = "cloudtrail-logs"
  cloud_watch_logs_group_arn     = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn      = aws_iam_role.cloudtrail[0].arn
  
  enable_logging                 = true
  include_global_service_events  = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-cloudtrail"
    Purpose = "Security Audit Trail"
  })

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail
  ]
}

# ============================================================================
# PHASE 3: IAM ROLES FOR FEDERATED ACCESS (WITH SAML TRUST POLICIES)
# ============================================================================

# IAM Role for Developer Access with SAML trust policy
resource "aws_iam_role" "federated_developer" {
  name               = "${var.project_name}-federated-developer"
  max_session_duration = 28800  # 8 hours

  # SAML federation trust policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_saml_provider.main.arn
        }
        Action = "sts:AssumeRoleWithSAML"
        Condition = {
          StringEquals = {
            "SAML:aud" = "https://signin.aws.amazon.com/saml"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-federated-developer"
    Purpose     = "Federated Developer Access"
    AccessLevel = "Developer"
  })
}

# Attach PowerUserAccess policy to developer role
resource "aws_iam_role_policy_attachment" "federated_developer" {
  role       = aws_iam_role.federated_developer.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/PowerUserAccess"
}

# IAM Role for Read-Only Access with SAML trust policy
resource "aws_iam_role" "federated_readonly" {
  name               = "${var.project_name}-federated-readonly"
  max_session_duration = 14400  # 4 hours

  # SAML federation trust policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_saml_provider.main.arn
        }
        Action = "sts:AssumeRoleWithSAML"
        Condition = {
          StringEquals = {
            "SAML:aud" = "https://signin.aws.amazon.com/saml"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-federated-readonly"
    Purpose     = "Federated Read-Only Access"
    AccessLevel = "ReadOnly"
  })
}

# Attach ReadOnlyAccess policy to readonly role
resource "aws_iam_role_policy_attachment" "federated_readonly" {
  role       = aws_iam_role.federated_readonly.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

# IAM Role for Administrative Access with SAML trust policy
resource "aws_iam_role" "federated_admin" {
  name               = "${var.project_name}-federated-admin"
  max_session_duration = 7200   # 2 hours (shorter for high privilege)

  # SAML federation trust policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_saml_provider.main.arn
        }
        Action = "sts:AssumeRoleWithSAML"
        Condition = {
          StringEquals = {
            "SAML:aud" = "https://signin.aws.amazon.com/saml"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-federated-admin"
    Purpose     = "Federated Administrative Access"
    AccessLevel = "Administrator"
  })
}

# Attach AdministratorAccess policy to admin role
resource "aws_iam_role_policy_attachment" "federated_admin" {
  role       = aws_iam_role.federated_admin.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}

# ============================================================================
# PHASE 4: SECURITY MONITORING AND NOTIFICATIONS
# ============================================================================

# SNS Topic for security notifications
resource "aws_sns_topic" "security_notifications" {
  count = var.notification_email != "" ? 1 : 0
  name  = "${var.project_name}-security-notifications"
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-security-notifications"
    Purpose = "Security Notifications"
  })
}

resource "aws_sns_topic_subscription" "email_notification" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_notifications[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch Event Rule for IAM changes
resource "aws_cloudwatch_event_rule" "iam_changes" {
  name        = "${var.project_name}-iam-changes"
  description = "Capture IAM changes for security monitoring"
  
  event_pattern = jsonencode({
    source      = ["aws.iam"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["iam.amazonaws.com"]
      eventName = [
        "CreateRole",
        "DeleteRole",
        "AttachRolePolicy",
        "DetachRolePolicy",
        "CreatePolicy",
        "DeletePolicy",
        "CreateUser",
        "DeleteUser",
        "AssumeRole",
        "AssumeRoleWithSAML"
      ]
    }
  })
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-iam-changes"
    Purpose = "Security Monitoring"
  })
}

# CloudWatch Event Target for SNS notifications
resource "aws_cloudwatch_event_target" "iam_changes_sns" {
  count     = var.notification_email != "" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.iam_changes.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_notifications[0].arn
}

# IAM Access Analyzer
resource "aws_accessanalyzer_analyzer" "main" {
  count         = var.enable_access_analyzer ? 1 : 0
  analyzer_name = "${var.project_name}-access-analyzer"
  type          = "ACCOUNT"
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-access-analyzer"
    Purpose = "IAM Access Analysis"
  })
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "phase1_info" {
  description = "Phase 1 test bucket information"
  value = {
    test_bucket_name = aws_s3_bucket.test_bucket.bucket
    aws_account_id   = local.current_account_id
    region           = local.current_region
  }
}

output "phase2_info" {
  description = "Phase 2 CloudTrail information"
  value = var.enable_cloudtrail ? {
    cloudtrail_bucket_name = aws_s3_bucket.cloudtrail[0].bucket
    cloudtrail_arn        = aws_cloudtrail.main[0].arn
    log_group_name        = aws_cloudwatch_log_group.cloudtrail[0].name
  } : null
}

output "phase3_info" {
  description = "Phase 3 IAM roles information"
  value = {
    federated_roles = {
      developer_role_arn = aws_iam_role.federated_developer.arn
      readonly_role_arn  = aws_iam_role.federated_readonly.arn
      admin_role_arn     = aws_iam_role.federated_admin.arn
    }
    saml_provider_arn = data.aws_iam_saml_provider.main.arn
    sns_topic_arn = var.notification_email != "" ? aws_sns_topic.security_notifications[0].arn : null
  }
}

output "phase4_info" {
  description = "Phase 4 SAML federation information"
  value = {
    saml_provider_arn = data.aws_iam_saml_provider.main.arn
    saml_provider_name = var.saml_provider_name
    federation_status = "Ready for testing - complete metadata upload first"
  }
}

output "next_steps" {
  description = "What to do next"
  value = <<-EOT
    
    ✅ Phase 1 Complete: Basic infrastructure working
    ✅ Phase 2 Complete: CloudTrail logging infrastructure  
    ✅ Phase 3 Complete: IAM roles with SAML trust policies
    🔄 Phase 4 In Progress: SAML federation setup
    
    🎯 Next Steps:
    
    1. Complete SSOCircle metadata upload to AWS SAML provider
    2. Test SAML federation with each role (Developer, ReadOnly, Admin)
    3. Configure role mappings in SSOCircle if needed
    4. Test complete login flow: SSOCircle → AWS Console
    5. Document successful federation patterns
    
    📚 Ready for federation testing!
    
  EOT
}