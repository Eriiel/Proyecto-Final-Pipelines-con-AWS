variable "aws_region" {
  description = "Región de AWS donde se crea todo"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo de todos los recursos (minúsculas y guiones, máx. 20). Debe coincidir con el bootstrap."
  type        = string
  default     = "triple-pipeline"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project_name))
    error_message = "Usa solo minúsculas, números y guiones (3 a 20 caracteres)."
  }
}

variable "environment" {
  description = "Nombre del ambiente (solo para etiquetas)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "Rango de IPs de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "backend_cpu" {
  description = "CPU de la tarea backend (unidades Fargate: 256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "backend_memory" {
  description = "Memoria de la tarea backend en MiB"
  type        = number
  default     = 512
}

variable "frontend_cpu" {
  description = "CPU de la tarea frontend"
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Memoria de la tarea frontend en MiB"
  type        = number
  default     = 512
}

variable "log_retention_days" {
  description = "Días que se guardan los logs en CloudWatch"
  type        = number
  default     = 7
}
