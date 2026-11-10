#!/usr/bin/env bash
# Comprueba que la aplicación responde a través del ALB.
# Uso: smoke-test.sh <url_base> <version_esperada>
set -euo pipefail

URL="$1"
ESPERADA="$2"
INTENTOS=20

echo "==> Smoke test contra $URL (versión esperada: $ESPERADA)"

for i in $(seq 1 "$INTENTOS"); do
  BODY=$(curl -fsS --max-time 5 "$URL/api/health" 2>/dev/null || true)
  VERSION=$(echo "$BODY" | jq -r '.version // empty' 2>/dev/null || true)
  if [ "$VERSION" = "$ESPERADA" ]; then
    echo "    Backend OK: $BODY"
    break
  fi
  echo "    Intento $i/$INTENTOS: backend responde '${VERSION:-sin respuesta}', esperando..."
  sleep 6
  if [ "$i" = "$INTENTOS" ]; then
    echo "::error::El backend no respondió con la versión $ESPERADA"
    exit 1
  fi
done

CODIGO=$(curl -s -o /tmp/index.html -w '%{http_code}' --max-time 5 "$URL/")
if [ "$CODIGO" != "200" ] || ! grep -q "Tablero de tareas" /tmp/index.html; then
  echo "::error::El frontend respondió HTTP $CODIGO o sin el contenido esperado"
  exit 1
fi
echo "    Frontend OK (HTTP 200)"

# Prueba de punta a punta: crear una tarea a través del ALB y borrarla
# después, para que el tablero quede limpio para la demo.
CREADA=$(curl -fsS --max-time 5 -X POST "$URL/api/tareas" \
  -H 'Content-Type: application/json' \
  -d '{"titulo":"Smoke test del pipeline"}')
echo "    Tarea creada: $(echo "$CREADA" | jq -c .)"
ID=$(echo "$CREADA" | jq -er '.id')
curl -fsS --max-time 5 -X DELETE "$URL/api/tareas/$ID"
echo "    Tarea $ID borrada (CRUD OK)"
echo "==> La aplicación está operativa en $URL"
