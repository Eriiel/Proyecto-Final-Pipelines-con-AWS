#!/usr/bin/env bash
# Despliega una imagen nueva en un servicio ECS con rollback automático.
#
# Uso: deploy-ecs-service.sh <cluster> <servicio> <imagen> [tareas_deseadas]
#
#  1. Lee la task definition actual del servicio.
#  2. Registra una revisión nueva cambiando solo la imagen y APP_VERSION.
#  3. Actualiza el servicio y espera a que quede estable.
#  4. Si falla o ECS hizo rollback (circuit breaker), vuelve a la revisión
#     anterior y termina con error para que el pipeline quede en rojo.
set -euo pipefail

CLUSTER="$1"
SERVICE="$2"
IMAGE="$3"
DESIRED="${4:-1}"
VERSION="${IMAGE##*:}"

echo "==> Desplegando $SERVICE con $IMAGE"

ANTERIOR=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].taskDefinition' --output text)
echo "    Task definition actual: $ANTERIOR"

aws ecs describe-task-definition --task-definition "$ANTERIOR" --query taskDefinition > td-actual.json

jq --arg IMG "$IMAGE" --arg VER "$VERSION" '
  .containerDefinitions[0].image = $IMG
  | .containerDefinitions[0].environment =
      ([.containerDefinitions[0].environment[]? | select(.name != "APP_VERSION")]
       + [{name: "APP_VERSION", value: $VER}])
  | del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
        .compatibilities, .registeredAt, .registeredBy, .deregisteredAt)
' td-actual.json > td-nueva.json

NUEVA=$(aws ecs register-task-definition --cli-input-json file://td-nueva.json \
  --query 'taskDefinition.taskDefinitionArn' --output text)
echo "    Task definition nueva:  $NUEVA"

aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" \
  --task-definition "$NUEVA" --desired-count "$DESIRED" >/dev/null

rollback() {
  echo "::error::El despliegue de $SERVICE falló: $1. Volviendo a $ANTERIOR"
  aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" \
    --task-definition "$ANTERIOR" >/dev/null
  aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
    --query 'services[0].events[0:5].message' --output text || true
  exit 1
}

echo "    Esperando a que el servicio quede estable (máx. ~10 min)..."
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE" \
  || rollback "el servicio no se estabilizó"

# Si el circuit breaker de ECS hizo rollback, el servicio queda "estable"
# pero con la revisión vieja: hay que comprobar cuál está corriendo.
CORRIENDO=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].deployments[?status==`PRIMARY`].taskDefinition | [0]' --output text)
[ "$CORRIENDO" = "$NUEVA" ] || rollback "ECS revirtió el despliegue (circuit breaker)"

echo "==> $SERVICE desplegado correctamente con la versión $VERSION"
