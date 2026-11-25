#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

set -a
# shellcheck disable=SC1091
. ./.env
set +a

if [ -f src/composer.lock ]; then
    echo "El codigo fuente ya esta descargado en ./src (svn update manual si querés actualizar)."
    exit 0
fi

mkdir -p src

if [ -d src/.svn ]; then
    echo "Checkout incompleto detectado; reanudando con svn cleanup + svn update ..."
    docker run --rm \
        -e SVN_USER -e SVN_PASSWORD \
        -v "$PWD/src:/work" -w /work \
        alpine:3.20 \
        sh -c 'apk add --no-cache subversion >/dev/null && svn cleanup --username "$SVN_USER" --password "$SVN_PASSWORD" /work && svn update --non-interactive --username "$SVN_USER" --password "$SVN_PASSWORD" /work'
else
    echo "Descargando $SVN_URL ..."
    docker run --rm \
        -e SVN_URL -e SVN_USER -e SVN_PASSWORD \
        -v "$PWD/src:/work" -w /work \
        alpine:3.20 \
        sh -c 'apk add --no-cache subversion >/dev/null && svn checkout --non-interactive --username "$SVN_USER" --password "$SVN_PASSWORD" "$SVN_URL" /work'
fi

echo "OK: codigo fuente en ./src"
