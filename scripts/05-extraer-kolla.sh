#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

RAR_FILE="${KOLLA_RAR:-instalador_kolla_4.10.3.rar}"

if [ -f src-kolla/composer.json ]; then
    echo "Kolla ya está extraído en ./src-kolla."
    exit 0
fi

if [ ! -f "$RAR_FILE" ]; then
    echo "No encuentro $RAR_FILE en la raíz del proyecto."
    echo "Descargalo del Portal de Servicios de Comunidad del SIU y ponelo acá."
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
