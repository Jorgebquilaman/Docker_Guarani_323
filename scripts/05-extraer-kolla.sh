#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

RAR_NAME="instalador_kolla_4.10.3.rar"
RAR_FILE="${KOLLA_RAR:-}"

if [ -f src-kolla/composer.json ]; then
    echo "Kolla ya está extraído en ./src-kolla."
    exit 0
fi

# Se busca primero en instaladores/ y luego en la raíz del proyecto.
if [ -z "$RAR_FILE" ]; then
    if [ -f "instaladores/$RAR_NAME" ]; then
        RAR_FILE="instaladores/$RAR_NAME"
    else
        RAR_FILE="$RAR_NAME"
    fi
fi

if [ ! -f "$RAR_FILE" ]; then
    echo "No encuentro $RAR_NAME."
    echo "Ponelo en ./instaladores/ o en la raíz del proyecto (descargalo del Portal de Servicios de Comunidad del SIU)."
    exit 1
fi

if ! command -v bsdtar >/dev/null 2>&1; then
    echo "Necesitás bsdtar (libarchive). En macOS viene con el sistema; en Linux:"
    echo "  apt-get install libarchive-tools"
    exit 1
fi

mkdir -p src-kolla
echo "Extrayendo $RAR_FILE en ./src-kolla ..."
bsdtar -xf "$RAR_FILE" -C src-kolla --strip-components=1

echo "OK: Kolla 4.10.3 extraído en ./src-kolla"
