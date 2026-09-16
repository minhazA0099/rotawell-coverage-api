variable "image" {
  description = "Image to deploy, pinned by digest. Supplied by the release pipeline, never typed by hand."
  type        = string
}

variable "app_version" {
  description = "Release version (annotated Git tag) reported by /version."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster from the platform stack."
  type        = string
}

variable "vpc_id" {
  description = "VPC from the network stack."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets across three Availability Zones."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for the service tasks."
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "Production HTTPS listener."
  type        = string
}

variable "alb_arn_suffix" {
  description = "Load balancer ARN suffix for CloudWatch alarm dimensions."
  type        = string
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for log encryption."
  type        = string
}

variable "alarm_actions" {
  description = "SNS topics for deployment alarms."
  type        = list(string)
  default     = []
}
