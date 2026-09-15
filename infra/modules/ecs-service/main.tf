locals {
  name      = "${var.service_name}-${var.environment}"
  env_short = var.environment == "production" ? "prd" : "stg"
}

data "aws_partition" "current" {}

data "aws_region" "current" {}

# --- Logs -------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

# --- IAM: separate execution and task roles -----------------------------------------------------

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The application's own permissions are attached to this role by the caller (least privilege).
resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${local.name}-codedeploy"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# --- Task definition: immutable, non-root, read-only root filesystem ----------------------------

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name                   = var.service_name
      image                  = var.image
      essential              = true
      user                   = "10001:10001"
      readonlyRootFilesystem = true
      portMappings           = [{ containerPort = var.container_port, protocol = "tcp" }]
      environment = [
        { name = "APP_ENV", value = var.environment },
        { name = "APP_VERSION", value = var.app_version },
      ]
      healthCheck = {
        command = [
          "CMD", "python", "-c",
          "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:${var.container_port}/healthz', timeout=2).status == 200 else 1)",
        ]
        interval    = 15
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])
}

# --- Blue and green target groups ---------------------------------------------------------------

resource "aws_lb_target_group" "blue" {
  #checkov:skip=CKV_AWS_378:TLS terminates at the HTTPS listener; ALB-to-task traffic stays inside private subnets.
  name                 = "${local.env_short}-${var.service_name}-blue"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "green" {
  #checkov:skip=CKV_AWS_378:TLS terminates at the HTTPS listener; ALB-to-task traffic stays inside private subnets.
  name                 = "${local.env_short}-${var.service_name}-green"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# --- Service ------------------------------------------------------------------------------------

resource "aws_ecs_service" "this" {
  #checkov:skip=CKV_AWS_332:The Fargate platform version is pinned so staging and production run the same platform; upgrades arrive as reviewed pull requests.
  name                              = local.name
  cluster                           = var.cluster_name
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  platform_version                  = var.fargate_platform_version
  health_check_grace_period_seconds = 30
  enable_execute_command            = false
  propagate_tags                    = "SERVICE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  lifecycle {
    # CodeDeploy owns the running task definition and the live target group, and service
    # autoscaling owns the task count. Ignoring exactly these attributes keeps the nightly drift
    # check quiet about expected changes, so any drift it does report is real. The running
    # revision is protected by SCPs that allow ECS writes only from the pipeline and CodeDeploy.
    ignore_changes = [task_definition, load_balancer, desired_count]
  }
}

# --- Deployment alarms: these trigger automatic rollback ----------------------------------------

resource "aws_cloudwatch_metric_alarm" "http_5xx_rate" {
  alarm_name          = "${local.name}-5xx-rate"
  alarm_description   = "Target 5xx responses above 1% of requests for 3 of 5 minutes. Stops and rolls back a deployment."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions

  metric_query {
    id          = "error_rate"
    expression  = "IF(requests > 0, 100 * errors / requests, 0)"
    label       = "5xx rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }

  metric_query {
    id = "requests"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "latency_p95" {
  alarm_name          = "${local.name}-p95-latency"
  alarm_description   = "p95 target response time above 1.5 s for 3 of 5 minutes. Stops and rolls back a deployment."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = 1.5
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  period              = 60
  extended_statistic  = "p95"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
}

# --- CodeDeploy blue-green with automatic rollback ----------------------------------------------

resource "aws_codedeploy_app" "this" {
  compute_platform = "ECS"
  name             = local.name
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  deployment_group_name  = local.name
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = var.deployment_config_name

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = var.bake_time_minutes
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms = [
      aws_cloudwatch_metric_alarm.http_5xx_rate.alarm_name,
      aws_cloudwatch_metric_alarm.latency_p95.alarm_name,
    ]
  }

  ecs_service {
    cluster_name = var.cluster_name
    service_name = aws_ecs_service.this.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.alb_listener_arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
}
