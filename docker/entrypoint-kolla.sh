#!/usr/bin/env bash
set -euo pipefail

PROJECT=/opt/kolla
LOG_DIR=/var/log/kolla
MARKER="$PROJECT/instalacion/.docker-instalado"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/entrypoint.log") 2>&1

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

psql_admin() {
    PGPASSWORD="$PG_ADMIN_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$PG_ADMIN_USER" "$@"
}

psql_db() {
    PGPASSWORD="$KOLLA_DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$KOLLA_DB_USER" "$@"
}

wait_for_db() {
    log "Esperando PostgreSQL en $DB_HOST:$DB_PORT ..."
    for _ in $(seq 1 180); do
        if psql_admin -d postgres -tAc 'select 1' >/dev/null 2>&1; then
            log "PostgreSQL disponible."
            return 0
        fi
        sleep 2
    done
    log "ERROR: PostgreSQL no respondio."
    return 1
}

asegurar_base() {
    if ! psql_admin -d postgres -tAc \
        "select 1 from pg_roles where rolname = '$KOLLA_DB_USER'" | grep -q 1; then
        log "Creando rol $KOLLA_DB_USER ..."
        psql_admin -d postgres -v ON_ERROR_STOP=1 -c \
            "CREATE ROLE $KOLLA_DB_USER LOGIN SUPERUSER PASSWORD '$KOLLA_DB_PASSWORD'"
    fi

    if ! psql_admin -d postgres -tAc \
        "select 1 from pg_database where datname = '$KOLLA_DB'" | grep -q 1; then
        log "Creando base $KOLLA_DB (LATIN1, owner $KOLLA_DB_USER) ..."
        psql_admin -d postgres -v ON_ERROR_STOP=1 -c \
            "CREATE DATABASE $KOLLA_DB OWNER $KOLLA_DB_USER ENCODING 'LATIN1' TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C'"
    else
        psql_admin -d postgres -v ON_ERROR_STOP=1 -c \
            "ALTER DATABASE $KOLLA_DB OWNER TO $KOLLA_DB_USER" >/dev/null
    fi
}

write_instalador_env() {
    cat > "$PROJECT/instalador.env" <<EOF
ENTORNO_PRODUCCION=0
INSTALADOR_TIMEOUT=1800

PROYECTO_DB_HOST="$DB_HOST"
PROYECTO_DB_PORT="$DB_PORT"
PROYECTO_DB_DBNAME="$KOLLA_DB"
PROYECTO_DB_USERNAME="$KOLLA_DB_USER"
PROYECTO_DB_PASSWORD="$KOLLA_DB_PASSWORD"
PROYECTO_DB_SCHEMA="kolla"
PROYECTO_DB_ENCODING="LATIN1"

TOBA_DB_HOST="$DB_HOST"
TOBA_DB_PORT="$DB_PORT"
TOBA_DB_DBNAME="$KOLLA_DB"
TOBA_DB_USERNAME="$KOLLA_DB_USER"
TOBA_DB_PASSWORD="$KOLLA_DB_PASSWORD"
TOBA_DB_SCHEMA="toba_kolla"
TOBA_DB_ENCODING="LATIN1"

TOBA_URL_BASE="http://localhost:${KOLLA_PORT}"
TOBA_USUARIO="toba"
TOBA_PASSWORD="$KOLLA_PASSWORD"
TOBA_ALIAS_PROYECTO="$KOLLA_ALIAS"
TOBA_ALIAS_NUCLEO="${KOLLA_ALIAS}/toba"
TOBA_ALIAS_TOBA_USUARIOS="${KOLLA_ALIAS}/toba_usuarios"
TOBA_ID_DESARROLLADOR=0
TOBA_FORZAR_HTTPS="off"
TOBA_SESSION_NAME="TOBA_KOLLA"

KOLLA_PROTOCOLO_URL_POST="http"
EOF
}

arreglar_permisos() {
    local dirs=(
        "$PROJECT/instalacion"
        "$PROJECT/www"
        "$PROJECT/www/img"
        "$PROJECT/procesos"
        "$PROJECT/temp"
        "$PROJECT/vendor/siu-toba/framework/www"
        "$PROJECT/vendor/siu-toba/framework/temp"
    )
    chown -R www-data:www-data "${dirs[@]}"
    chmod -R g+rwX "${dirs[@]}"
    chmod g+w "$PROJECT/instalacion/instalacion.ini" \
              "$PROJECT/instalacion/smtp.ini" 2>/dev/null || true
}

configurar_publica() {
    local conf="$PROJECT/instalacion/toba.conf"
    [ -f "$conf" ] || return 0
    if ! grep -q 'RewriteRule \^responder' "$conf"; then
        # Habilitaciones públicas (documentación oficial de Kolla 4.10)
        sed -i '/#Proyecto: kolla/,/<\/Directory>/ s#\(.*Require all granted.*\)#\1\n\tRewriteRule ^responder(.*)$ publica.php$1 [L]#' "$conf"
        log "RewriteRule de habilitaciones públicas agregada."
    fi
}

# ---------------------------------------------------------------- main ----
wait_for_db
asegurar_base

if [ ! -f "$MARKER" ]; then
    log "Primera instalacion de Kolla 4.10.3 ..."
    write_instalador_env

    # El volumen montado en instalacion/ existe vacío y el instalador lo toma por
    # "instalación existente". Se instala en un directorio temporal y se copia después.
    TMP_INST="$PROJECT/instalacion.tmp"
    rm -rf "$TMP_INST"
    # No crear el directorio: el instalador lo considera "instalación existente".

    cd "$PROJECT"
    TOBA_INSTALACION_DIR="$TMP_INST" php bin/instalador proyecto:instalar \
        --no-interaction \
        --no-validar-servicios \
        --wait-for-db=60 \
        --sin-mantenimiento \
        --no-progress \
        --log-output

    cp -a "$TMP_INST/." "$PROJECT/instalacion/"
    grep -rlI "$TMP_INST" "$PROJECT/instalacion" 2>/dev/null \
        | xargs -r sed -i "s#$TMP_INST#$PROJECT/instalacion#g"
    rm -rf "$TMP_INST"

    arreglar_permisos
    touch "$MARKER"
    log "Instalacion de Kolla finalizada."
fi

configurar_publica

ln -sfn "$PROJECT/instalacion/toba.conf" /etc/apache2/sites-enabled/kolla.conf
apachectl configtest

log "Apache de Kolla iniciado. URL: http://localhost:${KOLLA_PORT}${KOLLA_ALIAS}"
exec "$@"
