terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Estado remoto en S3 con bloqueo nativo (use_lockfile, Terraform >= 1.10).
  # "bucket" y "region" se pasan en "terraform init -backend-config=..."
  # para no dejar datos de la cuenta escritos en el código.
  backend "s3" {
    key          = "triple-pipeline/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Proyecto = var.project_name
      Ambiente = var.environment
      Gestion  = "terraform"
    }
  }
}
