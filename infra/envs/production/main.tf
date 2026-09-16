terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.64"
    }
  }

  # Partial configuration: the pipeline supplies bucket, key and region with -backend-config,
  # so no account details live in the repository. State is encrypted and locked.
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-1"

  # Ownership and cost-allocation tags on every resource (FinOps showback depends on them).
  default_tags {
    tags = {
      owner               = "squad-scheduling"
      service             = "coverage-api"
      environment         = "production"
      cost-centre         = "product-engineering"
      data-classification = "confidential"
      managed-by          = "terraform"
    }
  }
}

module "coverage_api" {
  source = "../../modules/ecs-service"

  service_name = "coverage-api"
  environment  = "production"
  image        = var.image
  app_version  = var.app_version

  # Sizing is the intended difference from staging; everything else comes from the same module.
  cpu           = 512
  memory        = 1024
  desired_count = 3

  # Phase 1: blue-green. Phase 2 (canary, business hours only) is a one-line change:
  #   deployment_config_name = "CodeDeployDefault.ECSCanary10Percent15Minutes"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  bake_time_minutes      = 30

  cluster_name       = var.cluster_name
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  security_group_ids = var.security_group_ids
  alb_listener_arn   = var.alb_listener_arn
  alb_arn_suffix     = var.alb_arn_suffix
  kms_key_arn        = var.kms_key_arn
  alarm_actions      = var.alarm_actions
}

output "codedeploy_app_name" {
  value = module.coverage_api.codedeploy_app_name
}

output "codedeploy_deployment_group_name" {
  value = module.coverage_api.codedeploy_deployment_group_name
}
