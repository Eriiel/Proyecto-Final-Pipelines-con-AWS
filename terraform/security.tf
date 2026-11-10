# -----------------------------------------------------------------------------
# SEGURIDAD: dos Security Groups.
#   - ALB: acepta HTTP (80) desde Internet.
#   - Tareas ECS: SOLO aceptan tráfico que venga del Security Group del ALB.
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Trafico HTTP publico hacia el balanceador"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde Internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Salida hacia las tareas"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-sg"
  description = "Tareas ECS: solo aceptan trafico del ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-ecs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  for_each = local.services

  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "Puerto ${each.value.port} del ${each.key} desde el ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Salida a Internet (descargar imagenes de ECR, enviar logs)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
