# -----------------------------------------------------------------------------
# ECR: un repositorio por componente (backend y frontend).
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "app" {
  for_each = local.services

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "MUTABLE" # "latest" se mueve; los tags por commit no se reutilizan
  force_delete         = true      # permite "terraform destroy" aunque tenga imágenes

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Conserva solo las últimas 10 imágenes para no acumular costos.
resource "aws_ecr_lifecycle_policy" "app" {
  for_each = aws_ecr_repository.app

  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar las ultimas 10 imagenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
