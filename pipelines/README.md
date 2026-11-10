# pipelines/

Herramienta elegida: **GitHub Actions**. Autenticación con AWS por **OIDC** (sin llaves de acceso guardadas).

| Archivo | Pipeline | Disparador |
|---|---|---|
| `1-infraestructura.yml` | Terraform: fmt → init → validate → plan → (aprobación) → apply/destroy | Push en `terraform/` (solo plan) o ejecución manual |
| `2-build-ecr.yml` | pytest + build Vite → `docker build` → tag `<sha>` y `latest` → push a ECR | Push en `aplicacion/` o manual |
| `3-deploy-ecs.yml` | Verifica imágenes en ECR → nueva task definition → `update-service` → espera estabilidad → smoke test | Al terminar bien el Pipeline 2, o manual con un tag (rollback) |
| `scripts/deploy-ecs-service.sh` | Despliegue de un servicio con rollback automático | Lo usa el Pipeline 3 |
| `scripts/smoke-test.sh` | Comprueba `/api/health` (con la versión nueva), el frontend y un POST real | Lo usa el Pipeline 3 |

## Ubicación real de los workflows

GitHub solo ejecuta los workflows que están en `.github/workflows/`. Esta carpeta guarda la copia que pide la entrega. Si editas un `.yml` aquí, ejecuta:

```bash
bash pipelines/sincronizar-workflows.sh
```

## Manejo de errores

- **Pipeline 1:** `fmt -check` y `validate` detienen el flujo antes del plan. El `apply` usa exactamente el plan revisado (artefacto) y necesita aprobación manual en el environment `infraestructura`. `concurrency` evita dos `apply` a la vez, y el estado en S3 tiene bloqueo (`use_lockfile`).
- **Pipeline 2:** si fallan las pruebas o el build del frontend, no se publica ninguna imagen. Al final se verifica con `aws ecr describe-images` que la imagen quedó en ECR.
- **Pipeline 3:** solo corre si el Pipeline 2 terminó en éxito. Si el servicio no se estabiliza, o si el circuit breaker de ECS revierte el despliegue, el script vuelve a la task definition anterior y marca el pipeline en rojo. El smoke test exige que `/api/health` responda **con la versión del commit** desplegado.
