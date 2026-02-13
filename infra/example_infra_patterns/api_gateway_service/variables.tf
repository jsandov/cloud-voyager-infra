# ---------------------------------------------------------------------------
# API Gateway Service Pattern — variables.tf
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------

variable "environment" {
  description = "Deployment environment (dev, staging, or prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Unique name identifying this service team. Used in resource naming and Lambda permission statement IDs to prevent collisions across teams sharing the same API Gateway."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.service_name))
    error_message = "service_name must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition     = length(var.service_name) >= 2 && length(var.service_name) <= 40
    error_message = "service_name must be between 2 and 40 characters."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Compute — Lambda
# ---------------------------------------------------------------------------

variable "image_uri" {
  description = "ECR container image URI for the service's Lambda function (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/billing-service:v1.0.0)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+$", var.image_uri))
    error_message = "image_uri must be a valid ECR image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/repo:tag)."
  }
}

# ---------------------------------------------------------------------------
# API Gateway — Route Configuration
# ---------------------------------------------------------------------------

variable "route_prefix" {
  description = "Path prefix assigned to this service by the platform team (e.g., /billing). All routes must start with this prefix. Enforced at plan time to prevent cross-team route collisions."
  type        = string

  validation {
    condition     = can(regex("^/[a-z0-9/_-]+$", var.route_prefix))
    error_message = "route_prefix must start with '/' and contain only lowercase letters, numbers, hyphens, underscores, and forward slashes."
  }
}

# ---------------------------------------------------------------------------
# Platform Team Remote State
# ---------------------------------------------------------------------------

variable "platform_state_bucket" {
  description = "S3 bucket name where the platform team stores their OpenTofu state file"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.platform_state_bucket))
    error_message = "platform_state_bucket must be a valid S3 bucket name."
  }
}

variable "platform_state_key" {
  description = "S3 object key (path) of the platform team's state file within the bucket"
  type        = string

  validation {
    condition     = length(var.platform_state_key) > 0
    error_message = "platform_state_key must not be empty."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC where the Lambda function will run"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (e.g., vpc-0abc1234def56789)."
  }
}

variable "vpc_subnet_ids" {
  description = "List of private subnet IDs for the Lambda function VPC configuration"
  type        = list(string)

  validation {
    condition     = length(var.vpc_subnet_ids) > 0
    error_message = "At least one subnet ID must be provided."
  }
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for the Lambda function VPC configuration"
  type        = list(string)

  validation {
    condition     = length(var.vpc_security_group_ids) > 0
    error_message = "At least one security group ID must be provided."
  }
}

# ---------------------------------------------------------------------------
# Encryption
# ---------------------------------------------------------------------------

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Lambda environment variables and CloudWatch logs at rest (SC-28)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a valid KMS key ARN (arn:aws:kms:...)."
  }
}
