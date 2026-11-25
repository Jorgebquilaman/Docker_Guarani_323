#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "ATENCION: esto borra la base de datos y toda la instalacion de Guaraní."
read -r -p "Continuar? [s/N] " respuesta
[ "$respuesta" = "s" ] || { echo "Cancelado."; exit 0; }

docker compose down -v
docker compose up -d --build

echo "Reinstalando desde cero. Seguí con: docker compose logs -f gestion"
