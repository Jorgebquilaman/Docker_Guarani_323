#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f src/composer.lock ]; then
    echo "Falta el codigo fuente. Ejecutá primero: ./scripts/01-svn-checkout.sh"
    exit 1
fi

docker compose up -d --build

set -a
# shellcheck disable=SC1091
. ./.env
set +a

echo
echo "Guaraní levantándose. Seguí el progreso con:"
echo "  docker compose logs -f gestion"
echo
echo "Gestión:     http://localhost:${GESTION_PORT}/guarani/3.23  (toba / toba)"
echo "Autogestión:  http://localhost:${W3_PORT:-8091}${AUTOGESTION_ALIAS:-/3w}"
echo "Preinscripción: http://localhost:${PREINSCRIPCION_PORT:-8092}/preinscripcion/${PREINSCRIPCION_PTO:-iupa}"
echo "  admin -> http://localhost:${PREINSCRIPCION_PORT:-8092}/preinscripcion_admin/${PREINSCRIPCION_PTO:-iupa}"
