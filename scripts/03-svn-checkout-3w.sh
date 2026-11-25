#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

set -a
# shellcheck disable=SC1091
. ./.env
set +a

export SVN_3W_URL="${SVN_3W_URL:-https://colab.siu.edu.ar/svn/guarani3/nodos/iupa/3w/trunk/3.23.0}"

if [ -f src-3w/composer.lock ]; then
    echo "El codigo de 3w ya esta descargado en ./src-3w."
    exit 0
fi

mkdir -p src-3w

if [ -d src-3w/.svn ]; then
    echo "Checkout incompleto detectado; reanudando ..."
    docker run --rm \
        -e SVN_USER -e SVN_PASSWORD \
        -v "$PWD/src-3w:/work" -w /work \
        alpine:3.20 \
        sh -c 'apk add --no-cache subversion >/dev/null && svn cleanup --username "$SVN_USER" --password "$SVN_PASSWORD" /work && svn update --non-interactive --username "$SVN_USER" --password "$SVN_PASSWORD" /work'
else
    echo "Descargando $SVN_3W_URL ..."
    docker run --rm \
        -e SVN_3W_URL -e SVN_USER -e SVN_PASSWORD \
        -v "$PWD/src-3w:/work" -w /work \
        alpine:3.20 \
        sh -c 'apk add --no-cache subversion >/dev/null && svn checkout --non-interactive --username "$SVN_USER" --password "$SVN_PASSWORD" "$SVN_3W_URL" /work'
fi

echo "OK: codigo de 3w en ./src-3w"
