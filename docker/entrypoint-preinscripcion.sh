#!/usr/bin/env bash
set -euo pipefail

PROJECT=/opt/preinscripcion
LOG_DIR=/var/log/preinscripcion
MARKER="$PROJECT/instalacion/.docker-instalado"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/entrypoint.log") 2>&1

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

psql_db() {
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$@"
}

wait_for_db() {
    log "Esperando PostgreSQL en $DB_HOST:$DB_PORT ..."
    for _ in $(seq 1 180); do
        if psql_db -d postgres -tAc 'select 1' >/dev/null 2>&1; then
            log "PostgreSQL disponible."
            return 0
        fi
        sleep 2
    done
    log "ERROR: PostgreSQL no respondio."
    return 1
}

asegurar_base() {
    if ! psql_db -d postgres -tAc \
        "select 1 from pg_database where datname = '$PREINSCRIPCION_DB'" | grep -q 1; then
        log "Creando base $PREINSCRIPCION_DB (LATIN1) ..."
        psql_db -d postgres -v ON_ERROR_STOP=1 -c \
            "CREATE DATABASE $PREINSCRIPCION_DB ENCODING 'LATIN1' TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C'"
    fi

    if ! psql_db -d "$PREINSCRIPCION_DB" -tAc \
        "select 1 from information_schema.tables where table_name = 'admin_usuarios'" \
        | grep -q 1; then
        log "Cargando esquema de Preinscripcion 3.23.0 ..."
        psql_db -d "$PREINSCRIPCION_DB" -v ON_ERROR_STOP=1 \
            -f "$PROJECT/BD/creacion/creacion_preinscripcion3_postgresql.sql" \
            > "$LOG_DIR/creacion_bd.log"
        log "Esquema cargado."
    fi
}

configurar_archivos() {
    cd "$PROJECT/instalacion"
    [ -f config.php ] || cp config_template.php config.php
    [ -f login.php ]  || cp login_template.php login.php
    [ -f alias.conf ] || cp alias_template.conf alias.conf
    php /usr/local/bin/configure-preinscripcion.php
    touch "$MARKER"
}

crear_admin() {
    if psql_db -d "$PREINSCRIPCION_DB" -tAc \
        "select 1 from admin_usuarios where usuario = '$PREINSCRIPCION_ADMIN_USER' and id_pto_acceso = '$PREINSCRIPCION_PTO'" \
        | grep -q 1; then
        log "Usuario administrador $PREINSCRIPCION_ADMIN_USER ya existe."
        return 0
    fi
    log "Creando usuario administrador $PREINSCRIPCION_ADMIN_USER ..."
    cd "$PROJECT/bin"
    printf '%s\n%s\n%s\n' \
        "$PREINSCRIPCION_ADMIN_USER" \
        "$PREINSCRIPCION_ADMIN_PASSWORD" \
        "$PREINSCRIPCION_PTO" \
        | ./preinscripcion user_admin
}

arreglar_permisos() {
    local dirs=(
        "$PROJECT/instalacion/temp"
        "$PROJECT/instalacion/log"
        "$PROJECT/instalacion/cache"
        "$PROJECT/src/siu/www/temp"
        "$PROJECT/src/siu/www/js/escalas"
    )
    chown -R www-data:www-data "${dirs[@]}"
    chmod -R g+rwX "${dirs[@]}"
}

# ---------------------------------------------------------------- main ----
wait_for_db
asegurar_base

if [ ! -f "$MARKER" ]; then
    configurar_archivos
    crear_admin
fi

arreglar_permisos

ln -sfn "$PROJECT/instalacion/alias.conf" /etc/apache2/sites-enabled/preinscripcion.conf
apachectl configtest

log "Apache de Preinscripcion iniciado."
log "Alumno: http://localhost:${PREINSCRIPCION_PORT:-8092}/preinscripcion/${PREINSCRIPCION_PTO}"
log "Admin:  http://localhost:${PREINSCRIPCION_PORT:-8092}/preinscripcion_admin/${PREINSCRIPCION_PTO}"
exec "$@"
