output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "task_definition_family" {
  description = "Task definition family the deploy pipeline registers new revisions into."
  value       = aws_ecs_task_definition.this.family
}

output "codedeploy_app_name" {
  description = "CodeDeploy application used by the release pipeline."
  value       = aws_codedeploy_app.this.name
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group used by the release pipeline."
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "log_group_name" {
  description = "CloudWatch log group for the service."
  value       = aws_cloudwatch_log_group.this.name
}
