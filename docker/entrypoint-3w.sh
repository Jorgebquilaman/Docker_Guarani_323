#!/usr/bin/env bash
set -euo pipefail

PROJECT=/opt/guarani-3w
LOG_DIR=/var/log/guarani-3w
MARKER="$PROJECT/instalacion/.docker-configurado"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/entrypoint.log") 2>&1

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

wait_for_db() {
    log "Esperando PostgreSQL en $CHULUPI_BASE_HOST:$CHULUPI_BASE_PORT ..."
    for _ in $(seq 1 180); do
        if PGPASSWORD="$CHULUPI_BASE_PASS" psql -h "$CHULUPI_BASE_HOST" \
              -p "$CHULUPI_BASE_PORT" -U "$CHULUPI_BASE_USER" \
              -d "$CHULUPI_BASE_NOMBRE" -tAc 'select 1' >/dev/null 2>&1; then
            log "PostgreSQL disponible."
            return 0
        fi
        sleep 2
    done
    log "ERROR: PostgreSQL no respondio."
    return 1
}

ajustar_config() {
    local cfg="$PROJECT/instalacion/config.php"
    [ -f "$cfg" ] || { log "ERROR: no se genero instalacion/config.php"; return 1; }

    # El script oficial genera config.php desde docker-templates/config.php.dist.
    # Ajustamos los valores que dependen del compose y desactivamos el captcha
    # (no hay keys de reCAPTCHA en un entorno local).
    php -r '
        $archivo = $GLOBALS["argv"][1];
        $config = require $archivo;
        $config["global"]["captcha"]["activo"] = false;
        $config["global"]["jasper_host"] = "gestion";
        $config["global"]["jasper_port"] = "8081";
        $config["global"]["url_gestion"] = getenv("URL_GESTION");
        $config["global"]["url_identidad_genero"] = "https://drive.google.com/file/d/1WFW6s9CAZro2mtOs1JIkBX0la6fzJP_o/view";
        $config["global"]["email_ayuda"] = getenv("AUTOGESTION_EMAIL_AYUDA");
        $config["global"]["accesos"]["des01"]["ua"] = (int) getenv("AUTOGESTION_UA");
        // El sed del script oficial rompe claves con caracteres especiales: se reescribe.
        $config["global"]["accesos"]["des01"]["database"]["pdo_passwd"] = getenv("CHULUPI_BASE_PASS");
        $contenido = "<?php\nreturn " . var_export($config, true) . ";\n";
        file_put_contents($archivo, $contenido);
    ' "$cfg"

    chown www-data:www-data "$cfg"
    touch "$MARKER"
    log "config.php ajustado (ua=${AUTOGESTION_UA}, jasper=gestion:8081, captcha off)."
}

configurar_personalizacion() {
    # Activa la personalización "iupa" sin sobrescribir el resto de config.php.
    local cfg="$PROJECT/instalacion/config.php"
    [ -f "$cfg" ] || return 0
    php -r '
        $archivo = $GLOBALS["argv"][1];
        $config = require $archivo;
        $config["global"]["usar_personalizaciones"] = true;
        $config["global"]["accesos"]["des01"]["personalizacion"] = "iupa";
        file_put_contents($archivo, "<?php\nreturn " . var_export($config, true) . ";\n");
    ' "$cfg"
    chown www-data:www-data "$cfg"
    log "Personalización iupa activada en 3w."
}

arreglar_permisos() {
    local dirs=(
        "$PROJECT/instalacion/log"
        "$PROJECT/instalacion/cache"
        "$PROJECT/instalacion/temp"
        "$PROJECT/instalacion/operaciones_inactivas"
        "$PROJECT/src/siu/www/js/escalas"
        "$PROJECT/src/siu/www/temp"
    )
    chown -R www-data:www-data "${dirs[@]}"
    chmod -R g+rwX "${dirs[@]}"
}

# ---------------------------------------------------------------- main ----
wait_for_db

if [ ! -f "$PROJECT/instalacion/config.php" ]; then
    log "Primera instalacion de Guarani 3w con bin/docker-instalar ..."
    cd "$PROJECT/bin"
    sh docker-instalar
    log "Instalacion de 3w finalizada."
fi

if [ ! -f "$MARKER" ]; then
    ajustar_config
fi

configurar_personalizacion
arreglar_permisos

# El script oficial crea guarani-autogestion.conf; nos quedamos con un solo alias.
rm -f /etc/apache2/sites-enabled/guarani-autogestion.conf
ln -sfn "$PROJECT/instalacion/alias.conf" /etc/apache2/sites-enabled/autogestion.conf
apachectl configtest

log "Apache de Autogestion iniciado. URL: ${URL_3W}"
exec "$@"
