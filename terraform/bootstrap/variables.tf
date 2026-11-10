variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre corto del proyecto (minúsculas y guiones, máx. 20 caracteres). Debe ser IGUAL al de terraform/ principal."
  type        = string
  default     = "triple-pipeline"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project_name))
    error_message = "Usa solo minúsculas, números y guiones (3 a 20 caracteres)."
  }
}

variable "github_repo" {
  description = "Repositorio de GitHub con formato usuario/repositorio (ej. mmgh/proyecto-final-devops)"
  type        = string
}
