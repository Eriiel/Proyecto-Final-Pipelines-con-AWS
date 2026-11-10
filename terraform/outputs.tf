output "app_url" {
  description = "URL pública de la aplicación"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repositories" {
  description = "URL de los repositorios ECR"
  value       = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "ecs_cluster" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_services" {
  description = "Nombres de los servicios ECS"
  value       = [for s in aws_ecs_service.app : s.name]
}
