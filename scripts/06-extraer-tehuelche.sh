#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

RAR_NAME="instalador_tehuelche_4.5.2.rar"
RAR_FILE="${TEHUELCHE_RAR:-}"

if [ -f src-tehuelche/composer.json ]; then
    echo "Tehuelche ya está extraído en ./src-tehuelche."
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

mkdir -p src-tehuelche
echo "Extrayendo $RAR_FILE en ./src-tehuelche ..."
bsdtar -xf "$RAR_FILE" -C src-tehuelche --strip-components=1

echo "OK: Tehuelche 4.5.2 extraído en ./src-tehuelche"
