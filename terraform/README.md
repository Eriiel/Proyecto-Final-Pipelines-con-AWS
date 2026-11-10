# terraform/

| Carpeta | Qué crea | Cómo se ejecuta |
|---|---|---|
| `bootstrap/` | Bucket S3 del estado, proveedor OIDC de GitHub y rol IAM para los pipelines | **Una vez**, desde tu PC |
| `.` (raíz) | VPC, subredes, Security Groups, ECR, ALB, ECS Fargate, IAM, CloudWatch | **Pipeline 1** (GitHub Actions) |

## 1. Bootstrap (una sola vez)

Requisitos: Terraform ≥ 1.10, AWS CLI v2 y un usuario con permisos de administrador configurado con `aws configure`.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # edita github_repo
terraform init
terraform apply
```

Copia las dos salidas (`tf_state_bucket` y `github_actions_role_arn`) a las variables del repositorio de GitHub (ver README principal).

> El estado del bootstrap queda local (`terraform.tfstate` en esa carpeta). No lo subas al repo (ya está en `.gitignore`), pero guárdalo para poder hacer `terraform destroy` al final.

## 2. Infraestructura principal

Normalmente la crea el **Pipeline 1**. Si quieres probar desde tu PC:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config="bucket=<tf_state_bucket>" -backend-config="region=us-east-1"
terraform plan
terraform apply
```

## Recursos creados

- **Red:** VPC `10.0.0.0/16`, 2 subredes públicas en 2 AZ, Internet Gateway y tabla de rutas.
- **Seguridad:** SG del ALB (HTTP 80 desde Internet) y SG de las tareas (solo acepta tráfico del ALB).
- **ECR:** `<proyecto>-backend` y `<proyecto>-frontend`, con escaneo al subir y política de retención (últimas 10 imágenes).
- **Acceso:** Application Load Balancer. `/api/*` va al backend y el resto al frontend.
- **ECS:** cluster Fargate, 2 task definitions, 2 servicios con circuit breaker y rollback automático.
- **IAM:** rol de ejecución de tareas (`AmazonECSTaskExecutionRolePolicy`).
- **Logs:** un log group de CloudWatch por servicio (7 días).

Los servicios se crean con `desired_count = 0` porque al aplicar Terraform todavía no hay imágenes. El Pipeline 3 los sube a 1 tarea con la imagen real, y Terraform ignora esos dos campos para no pisar los despliegues.
