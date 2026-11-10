#!/usr/bin/env bash
# GitHub Actions solo ejecuta los workflows que están en .github/workflows/.
# Esta carpeta (pipelines/) es la copia que pide la entrega.
# Edita aquí y ejecuta este script para copiarlos:
#   bash pipelines/sincronizar-workflows.sh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .github/workflows
cp pipelines/*.yml .github/workflows/
echo "Workflows copiados a .github/workflows/:"
ls -1 .github/workflows/
