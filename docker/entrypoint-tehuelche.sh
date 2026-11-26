#!/usr/bin/env bash
set -euo pipefail

PROJECT=/opt/tehuelche
LOG_DIR=/var/log/tehuelche
MARKER="$PROJECT/instalacion/.docker-instalado"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/entrypoint.log") 2>&1

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

psql_admin() {
    PGPASSWORD="$PG_ADMIN_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$PG_ADMIN_USER" "$@"
}

psql_db() {
    PGPASSWORD="$TEHUELCHE_DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$TEHUELCHE_DB_USER" "$@"
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
        "select 1 from pg_roles where rolname = '$TEHUELCHE_DB_USER'" | grep -q 1; then
        log "Creando rol $TEHUELCHE_DB_USER ..."
        psql_admin -d postgres -v ON_ERROR_STOP=1 -c \
            "CREATE ROLE $TEHUELCHE_DB_USER LOGIN SUPERUSER PASSWORD '$TEHUELCHE_DB_PASSWORD'"
    fi

    if ! psql_admin -d postgres -tAc \
        "select 1 from pg_database where datname = '$TEHUELCHE_DB'" | grep -q 1; then
        log "Creando base $TEHUELCHE_DB (LATIN1, owner $TEHUELCHE_DB_USER) ..."
        psql_admin -d postgres -v ON_ERROR_STOP=1 -c \
            "CREATE DATABASE $TEHUELCHE_DB OWNER $TEHUELCHE_DB_USER ENCODING 'LATIN1' TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C'"
    else
        psql_admin -d postgres -v ON_ERROR_STOP=1 -c \
            "ALTER DATABASE $TEHUELCHE_DB OWNER TO $TEHUELCHE_DB_USER" >/dev/null
    fi
}

write_instalador_env() {
    cat > "$PROJECT/instalador.env" <<EOF
ENTORNO_PRODUCCION=0
INSTALADOR_TIMEOUT=1800

PROYECTO_DB_HOST="$DB_HOST"
PROYECTO_DB_PORT="$DB_PORT"
PROYECTO_DB_DBNAME="$TEHUELCHE_DB"
PROYECTO_DB_USERNAME="$TEHUELCHE_DB_USER"
PROYECTO_DB_PASSWORD="$TEHUELCHE_DB_PASSWORD"
PROYECTO_DB_SCHEMA="tehuelche"
PROYECTO_DB_ENCODING="LATIN1"

TOBA_DB_HOST="$DB_HOST"
TOBA_DB_PORT="$DB_PORT"
TOBA_DB_DBNAME="$TEHUELCHE_DB"
TOBA_DB_USERNAME="$TEHUELCHE_DB_USER"
TOBA_DB_PASSWORD="$TEHUELCHE_DB_PASSWORD"
TOBA_DB_SCHEMA="toba_tehuelche"
TOBA_DB_ENCODING="LATIN1"

TOBA_URL_BASE="http://localhost:${TEHUELCHE_PORT}"
TOBA_USUARIO="toba"
TOBA_PASSWORD="$TEHUELCHE_PASSWORD"
TOBA_ALIAS_PROYECTO="$TEHUELCHE_ALIAS"
TOBA_ALIAS_NUCLEO="${TEHUELCHE_ALIAS}/toba"
TOBA_ALIAS_TOBA_USUARIOS="${TEHUELCHE_ALIAS}/toba_usuarios"
TOBA_ID_DESARROLLADOR=0
TOBA_FORZAR_HTTPS="off"
TOBA_SESSION_NAME="TOBA_TEHUELCHE"
EOF
}

arreglar_permisos() {
    local dirs=(
        "$PROJECT/instalacion"
        "$PROJECT/www"
        "$PROJECT/www/img"
        "$PROJECT/temp"
        "$PROJECT/vendor/siu-toba/framework/www"
        "$PROJECT/vendor/siu-toba/framework/temp"
    )
    chown -R www-data:www-data "${dirs[@]}"
    chmod -R g+rwX "${dirs[@]}"
    chmod g+w "$PROJECT/instalacion/instalacion.ini" \
              "$PROJECT/instalacion/smtp.ini" 2>/dev/null || true
}

# ---------------------------------------------------------------- main ----
wait_for_db
asegurar_base

if [ ! -f "$MARKER" ]; then
    log "Primera instalacion de Tehuelche 4.5.2 ..."
    write_instalador_env

    # Igual que en el script oficial docker/bin/crear-bd.sh: el instalador rechaza
    # un directorio de instalación ya existente, así que se instala en uno temporal.
    TMP_INST="$PROJECT/instalacion.tmp"
    rm -rf "$TMP_INST"

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
    log "Instalacion de Tehuelche finalizada."
fi

ln -sfn "$PROJECT/instalacion/toba.conf" /etc/apache2/sites-enabled/tehuelche.conf
apachectl configtest

log "Apache de Tehuelche iniciado. URL: http://localhost:${TEHUELCHE_PORT}${TEHUELCHE_ALIAS}"
exec "$@"
