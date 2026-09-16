variable "service_name" {
  description = "Short service name used in resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.service_name))
    error_message = "service_name must be lower-case letters, digits or hyphens, at most 20 characters."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "image" {
  description = "Container image to run. Must be pinned by digest so every environment runs the exact artefact CI built and scanned."
  type        = string

  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.image))
    error_message = "image must be referenced by digest (name@sha256:<64 hex characters>), never by a mutable tag."
  }
}

variable "app_version" {
  description = "Release version (the annotated Git tag), injected at deploy time and reported by /version."
  type        = string
}

variable "container_port" {
  description = "Port gunicorn listens on inside the container."
  type        = number
  default     = 8000
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
}

variable "desired_count" {
  description = "Initial number of tasks. Service autoscaling owns the running count after creation."
  type        = number
}

variable "fargate_platform_version" {
  description = "Pinned Fargate platform version, so every environment runs the same platform."
  type        = string
  default     = "1.4.0"
}

variable "cluster_name" {
  description = "Name of the ECS cluster (created by the platform stack)."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the target groups."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets across three Availability Zones."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the tasks."
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "Production HTTPS listener whose traffic CodeDeploy moves between the blue and green target groups."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the load balancer, used as the CloudWatch metric dimension for deployment alarms."
  type        = string
}

variable "deployment_config_name" {
  description = "CodeDeploy configuration. Phase 1 uses blue-green (all at once); Phase 2 moves web traffic to a canary."
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"

  validation {
    condition = contains([
      "CodeDeployDefault.ECSAllAtOnce",
      "CodeDeployDefault.ECSCanary10Percent5Minutes",
      "CodeDeployDefault.ECSCanary10Percent15Minutes",
      "CodeDeployDefault.ECSLinear10PercentEvery1Minutes",
      "CodeDeployDefault.ECSLinear10PercentEvery3Minutes",
    ], var.deployment_config_name)
    error_message = "deployment_config_name must be one of the approved CodeDeploy ECS configurations."
  }
}

variable "bake_time_minutes" {
  description = "How long the previous (blue) task set is kept after traffic moves, so rollback stays a traffic switch."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 365
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key used to encrypt logs."
  type        = string
}

variable "alarm_actions" {
  description = "SNS topic ARNs notified when a deployment alarm fires."
  type        = list(string)
  default     = []
}
