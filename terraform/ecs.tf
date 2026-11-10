# -----------------------------------------------------------------------------
# ECS FARGATE: cluster, task definitions y servicios.
#
# Decisión clave: Terraform crea los servicios con desired_count = 0, porque al
# aplicar la infraestructura todavía no hay imágenes en ECR. El Pipeline 3
# registra la task definition con la imagen real y sube el servicio a 1 tarea.
# Por eso Terraform ignora los cambios en task_definition y desired_count:
# volver a ejecutar el Pipeline 1 NO pisa lo que desplegó el Pipeline 3.
# -----------------------------------------------------------------------------

locals {
  services = {
    backend = {
      port        = 8000
      cpu         = var.backend_cpu
      memory      = var.backend_memory
      health_path = "/api/health"
    }
    frontend = {
      port        = 80
      cpu         = var.frontend_cpu
      memory      = var.frontend_memory
      health_path = "/"
    }
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled" # se puede activar; tiene costo adicional
  }
}

resource "aws_cloudwatch_log_group" "app" {
  for_each = local.services

  name              = "/ecs/${var.project_name}/${each.key}"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "app" {
  for_each = local.services

  family                   = "${var.project_name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = each.key
    image     = "${aws_ecr_repository.app[each.key].repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = each.value.port
      protocol      = "tcp"
    }]
    environment = [
      { name = "APP_VERSION", value = "inicial" },
      { name = "AWS_REGION", value = var.aws_region },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app[each.key].name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = each.key
      }
    }
  }])
}

resource "aws_ecs_service" "app" {
  for_each = local.services

  name                              = each.key
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.app[each.key].arn
  desired_count                     = 0
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 30

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }

  # Si un despliegue falla los health checks, ECS vuelve solo a la versión anterior.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener_rule.api,
    aws_iam_role_policy_attachment.ecs_execution,
  ]
}
