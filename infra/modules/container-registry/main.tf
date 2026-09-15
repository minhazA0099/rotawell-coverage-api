terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

variable "name" {
  description = "Repository name."
  type        = string
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key used to encrypt images."
  type        = string
}

variable "untagged_expiry_days" {
  description = "Untagged images older than this are deleted."
  type        = number
  default     = 14
}

variable "replica_region" {
  description = "Recovery region that receives a copy of every image, so a regional rebuild has something to deploy."
  type        = string
  default     = "eu-central-1"
}

data "aws_caller_identity" "current" {}

# Immutable tags: a tag can never be moved to different content, so a digest recorded in a
# deployment always means the image CI scanned. Scan on push catches known CVEs on arrival.
resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Registry-level replication: every image pushed here is copied to the recovery region.
resource "aws_ecr_replication_configuration" "this" {
  replication_configuration {
    rule {
      destination {
        region      = var.replica_region
        registry_id = data.aws_caller_identity.current.account_id
      }

      repository_filter {
        filter      = var.name
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

output "repository_url" {
  description = "Registry URL that deploys reference by digest."
  value       = aws_ecr_repository.this.repository_url
}
