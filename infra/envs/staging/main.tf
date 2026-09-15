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
      environment         = "staging"
      cost-centre         = "product-engineering"
      data-classification = "internal"
      managed-by          = "terraform"
    }
  }
}

module "coverage_api" {
  source = "../../modules/ecs-service"

  service_name = "coverage-api"
  environment  = "staging"
  image        = var.image
  app_version  = var.app_version

  # Smaller than production; the module, engine versions and deployment mechanism are identical.
  cpu           = 256
  memory        = 512
  desired_count = 1

  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  bake_time_minutes      = 10

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
