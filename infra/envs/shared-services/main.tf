terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.64"
    }
  }

  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      owner               = "platform"
      service             = "coverage-api"
      environment         = "shared-services"
      cost-centre         = "platform"
      data-classification = "internal"
      managed-by          = "terraform"
    }
  }
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for image encryption."
  type        = string
}

# One registry in the Shared Services account; staging and production pull the same digest.
module "registry" {
  source = "../../modules/container-registry"

  name        = "coverage-api"
  kms_key_arn = var.kms_key_arn
}

output "repository_url" {
  value = module.registry.repository_url
}
