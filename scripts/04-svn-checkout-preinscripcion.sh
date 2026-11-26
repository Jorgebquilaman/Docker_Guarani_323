#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

set -a
# shellcheck disable=SC1091
. ./.env
set +a

export SVN_PREINSCRIPCION_URL="${SVN_PREINSCRIPCION_URL:-https://colab.siu.edu.ar/svn/guarani3/nodos/iupa/preinscripcion/trunk/3.23.0}"

if [ -f src-preinscripcion/composer.lock ]; then
    echo "El codigo de Preinscripcion ya esta descargado en ./src-preinscripcion."
    exit 0
fi

mkdir -p src-preinscripcion

if [ -d src-preinscripcion/.svn ]; then
    echo "Checkout incompleto detectado; reanudando ..."
    docker run --rm \
        -e SVN_USER -e SVN_PASSWORD \
        -v "$PWD/src-preinscripcion:/work" -w /work \
        alpine:3.20 \
        sh -c 'apk add --no-cache subversion >/dev/null && svn cleanup --username "$SVN_USER" --password "$SVN_PASSWORD" /work && svn update --non-interactive --username "$SVN_USER" --password "$SVN_PASSWORD" /work'
else
    echo "Descargando $SVN_PREINSCRIPCION_URL ..."
    docker run --rm \
        -e SVN_PREINSCRIPCION_URL -e SVN_USER -e SVN_PASSWORD \
        -v "$PWD/src-preinscripcion:/work" -w /work \
        alpine:3.20 \
        sh -c 'apk add --no-cache subversion >/dev/null && svn checkout --non-interactive --username "$SVN_USER" --password "$SVN_PASSWORD" "$SVN_PREINSCRIPCION_URL" /work'
fi

echo "OK: codigo de Preinscripcion en ./src-preinscripcion"
