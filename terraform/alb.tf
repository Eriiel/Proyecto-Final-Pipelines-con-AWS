# -----------------------------------------------------------------------------
# ALB: punto de entrada único.
#   /api/*  -> servicio backend (FastAPI, puerto 8000)
#   /*      -> servicio frontend (nginx, puerto 80)
# Así frontend y backend comparten dominio y no hace falta configurar CORS.
# -----------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "app" {
  for_each = local.services

  name                 = "${var.project_name}-${each.key}"
  port                 = each.value.port
  protocol             = "HTTP"
  target_type          = "ip" # requerido por Fargate (awsvpc)
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 15

  health_check {
    path                = each.value.health_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app["frontend"].arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app["backend"].arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
