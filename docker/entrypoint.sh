#!/usr/bin/env bash
set -euo pipefail

PROJECT=/opt/guarani
LOG_DIR=/var/log/guarani
MARKER="$PROJECT/instalacion/.docker-instalado"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/entrypoint.log") 2>&1

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

wait_for_db() {
    log "Esperando PostgreSQL en $DB_HOST:$DB_PORT ..."
    for _ in $(seq 1 180); do
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" \
              -U "$DB_USER" -d "$DB_NAME" -tAc 'select 1' >/dev/null 2>&1; then
            log "PostgreSQL disponible."
            return 0
        fi
        sleep 2
    done
    log "ERROR: PostgreSQL no respondio."
    return 1
}

write_instalador_env() {
    cat > "$PROJECT/instalador.env" <<EOF
ENTORNO_PRODUCCION="0"
INSTALADOR_TIMEOUT="1800"

PROYECTO_DB_HOST="$DB_HOST"
PROYECTO_DB_PORT="$DB_PORT"
PROYECTO_DB_DBNAME="$DB_NAME"
PROYECTO_DB_USERNAME="$DB_USER"
PROYECTO_DB_PASSWORD="$DB_PASSWORD"
PROYECTO_DB_SCHEMA="negocio"
PROYECTO_DB_ENCODING="LATIN1"

TOBA_DB_HOST="$DB_HOST"
TOBA_DB_PORT="$DB_PORT"
TOBA_DB_DBNAME="$DB_NAME"
TOBA_DB_USERNAME="$DB_USER"
TOBA_DB_PASSWORD="$DB_PASSWORD"
TOBA_DB_SCHEMA="desarrollo"
TOBA_DB_ENCODING="LATIN1"

TOBA_URL_BASE="http://localhost:${GESTION_PORT}"
TOBA_USUARIO="toba"
TOBA_PASSWORD="$TOBA_PASSWORD"
TOBA_PROYECTO_DIR="$PROJECT"
TOBA_INSTALACION_DIR="$PROJECT/instalacion"
TOBA_ALIAS_PROYECTO="/guarani"
TOBA_ALIAS_NUCLEO="/toba_proyecto"
TOBA_ALIAS_TOBA_USUARIOS="/toba_usuarios"
TOBA_ALIAS_TOBA_EDITOR="/toba_editor"
TOBA_ALIAS_TOBA_REFERENCIA="/toba_referencia"
TOBA_ID_DESARROLLADOR=0
TOBA_SESSION_NAME="TOBA_GUARANI3"
TOBA_FORZAR_HTTPS="off"
TOBA_SALT="$TOBA_SALT"
EOF
}

instalar_con_instalador() {
    log "Instalando con bin/instalador proyecto:instalar ..."
    cd "$PROJECT"
    php bin/instalador proyecto:instalar \
        --no-interaction \
        --no-validar-servicios \
        --wait-for-db=60 \
        --sin-mantenimiento \
        --no-progress \
        --log-output
}

instalar_segun_documentacion() {
    log "Falló el instalador nuevo; usando el procedimiento documentado ..."
    cd "$PROJECT/bin"
    export TOBA_INSTANCIA=desarrollo
    export TOBA_INSTALACION_DIR="$PROJECT/instalacion"
    export TOBA_DIR="$PROJECT/vendor/siu-toba/framework"

    printf '%s\n' \
        "toba_guarani3" \
        "0" \
        "n" \
        "guarani3" \
        "$DB_HOST" \
        "$DB_PORT" \
        "$DB_USER" \
        "$DB_PASSWORD" \
        "$DB_NAME" \
        "desarrollo" \
        "$TOBA_PASSWORD" \
        | "$TOBA_DIR/bin/toba" instalacion instalar

    configurar_menu
    printf 's\n' | ./guarani cargar -d "$PROJECT"
    ./guarani instalar
    ./guarani crear_auditoria -f guarani
}

configurar_menu() {
    # La plantilla trae 'menu = #' (valor inválido): se reemplaza por menú KDE (2).
    if ! grep -qE '^menu[[:space:]]*=[[:space:]]*[012][[:space:]]*$' "$PROJECT/menu.ini" 2>/dev/null; then
        printf 'menu=2\n' > "$PROJECT/menu.ini"
        log "menu.ini configurado (menu=2)"
    fi
}

configurar_fop() {
    local ini="$PROJECT/instalacion/instalacion.ini"
    local fop="$PROJECT/php/3ros/fop/fop"
    if [ ! -x "$fop" ]; then
        fop=$(find "$PROJECT" -type f -name fop -perm -u+x 2>/dev/null | head -1 || true)
    fi
    if [ -n "$fop" ] && [ -f "$ini" ] && ! grep -q '^\[xslfo\]' "$ini"; then
        printf '\n[xslfo]\nfop=%s\n' "$fop" >> "$ini"
        log "fop configurado en $fop"
    fi
}

arreglar_permisos() {
    local dirs=(
        "$PROJECT/www"
        "$PROJECT/temp"
        "$PROJECT/instalacion"
        "$PROJECT/metadatos_compilados"
        "$PROJECT/vendor/siu-toba/framework/www"
        "$PROJECT/vendor/siu-toba/framework/temp"
    )
    chown -R www-data:www-data "${dirs[@]}"
    chmod -R g+rwX "${dirs[@]}"
}

arrancar_javabridge() {
    local lib="$PROJECT/vendor/siu-toba/jasper/JavaBridge/WEB-INF/lib"
    if [ ! -d "$lib" ]; then
        lib=$(dirname "$(find "$PROJECT/vendor/siu-toba/jasper" -name 'JavaBridge.jar' 2>/dev/null | head -1)")
    fi
    if [ ! -d "$lib" ] || [ "$lib" = "." ]; then
        log "ADVERTENCIA: no se encontraron librerias Jasper; los reportes no funcionaran."
        return 0
    fi
    log "Iniciando JavaBridge Jasper en 8081 ..."
    nohup java \
        -cp "$lib/*" \
        -Djavax.xml.parsers.DocumentBuilderFactory=com.sun.org.apache.xerces.internal.jaxp.DocumentBuilderFactoryImpl \
        -Djavax.xml.parsers.SAXParserFactory=com.sun.org.apache.xerces.internal.jaxp.SAXParserFactoryImpl \
        -Duser.language=es -Duser.country=AR -Djava.awt.headless=true \
        php.java.bridge.Standalone SERVLET:8081 3 \
        >> "$LOG_DIR/javabridge.log" 2>&1 &
}

# ---------------------------------------------------------------- main ----
wait_for_db

if [ -f "$MARKER" ]; then
    log "Instalacion previa detectada; omitiendo instalacion."
else
    log "Primera instalacion de SIU-Guaraní $PROJECT ..."
    write_instalador_env
    # El metodo documentado es el que funciona en 3.23.0; el instalador nuevo
    # queda como respaldo por si cambia en una revision posterior.
    if ! instalar_segun_documentacion; then
        log "El metodo documentado fallo; probando bin/instalador ..."
        instalar_con_instalador
    fi
    arreglar_permisos
    touch "$MARKER"
    log "Instalacion finalizada."
fi

# Configuraciones idempotentes (tambien en reinicios)
configurar_menu
configurar_fop

# Apache: toba.conf generado por la instalacion
if [ -f "$PROJECT/instalacion/toba.conf" ]; then
    ln -sfn "$PROJECT/instalacion/toba.conf" /etc/apache2/sites-enabled/gestion.conf
else
    log "ADVERTENCIA: no existe instalacion/toba.conf"
fi
apachectl configtest

arrancar_javabridge

log "Apache iniciado. Gestión: http://localhost:${GESTION_PORT}/guarani/3.23"
exec "$@"
