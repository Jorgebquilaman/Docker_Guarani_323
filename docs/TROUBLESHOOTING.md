# Resolución de problemas

## El checkout SVN falla con 401

Síntoma: `svn: E170001: Authorization failed` o `401 Unauthorized`.

```bash
# Probar credenciales con curl (Digest)
curl -s -o /dev/null -w "%{http_code}\n" --digest \
  -u 'TU_USUARIO:TU_CLAVE' \
  https://colab.siu.edu.ar/svn/guarani3/nodos/iupa/
```

- `200`: credenciales correctas y con acceso al nodo.
- `401`: usuario o clave incorrectos (recordar que la clave puede tener `!`, `&`, `%`, `^`;
  en `.env` debe ir entre comillas simples).
- `403`: el usuario existe pero no tiene permisos sobre esa ruta. Pedir acceso por GdS.

Si el checkout se cortó a mitad, volver a ejecutar `./scripts/01-svn-checkout.sh`: reanuda
con `svn cleanup` + `svn update`.

## El puerto ya está en uso

```
Error response from daemon: driver failed programming external connectivity ... bind: address already in use
```

Ver qué lo ocupa y cambiar el valor en `.env`:

```bash
lsof -nP -iTCP -sTCP:LISTEN | grep -E ':(8090|5434)\b'
```

```dotenv
GESTION_PORT=8091
DB_PORT_HOST=5435
```

Luego `docker compose down && ./scripts/02-up.sh`. La URL de acceso cambia al puerto nuevo.

## La app muestra "Class guarani_menu_# not found" o una página vacía

El `menu.ini` quedó con el valor de plantilla. Corregir:

```bash
docker compose exec gestion sh -c "printf 'menu=2\n' > /opt/guarani/menu.ini"
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8090/guarani/3.23/
```

El entrypoint ya lo corrige solo en cada arranque; si aparece de nuevo, verificar que la
imagen esté actualizada (`./scripts/02-up.sh`).

## Error de conexión a PostgreSQL durante la instalación

```bash
docker compose logs db | tail -40
docker compose exec db pg_isready -U "$POSTGRES_USER" -d guarani3
```

- Si `db` no está `healthy`, esperar unos segundos: `gestion` tiene un healthcheck con
  `start_period` de 600 s.
- Si la clave cambió en `.env` después de crear el volumen, el Postgres viejo conserva la
  clave anterior. Hacer `./scripts/reset.sh` o cambiarla dentro del contenedor:

```bash
docker compose exec -T db psql -U postgres -d postgres \
  -c "ALTER ROLE $POSTGRES_USER WITH PASSWORD 'NUEVA_CLAVE';"
```

## Error de permisos (Apache no puede escribir)

```bash
docker compose exec gestion sh -c '
  chown -R www-data:www-data /opt/guarani/www /opt/guarani/temp \
    /opt/guarani/instalacion /opt/guarani/metadatos_compilados \
    /opt/guarani/vendor/siu-toba/framework/www \
    /opt/guarani/vendor/siu-toba/framework/temp
  chmod -R g+rwX /opt/guarani/www /opt/guarani/temp /opt/guarani/instalacion
'
docker compose restart gestion
```

## Los reportes Jasper no generan PDF

```bash
docker compose exec gestion sh -c 'pgrep -af php.java.bridge.Standalone'
docker compose exec gestion tail -50 /var/log/guarani/javabridge.log
docker compose exec gestion grep -A2 '^\[xslfo\]' /opt/guarani/instalacion/instalacion.ini
```

- Si no hay proceso Java: ver el log. Puede faltar memoria o haber un error de classpath.
- Si falta `[xslfo]`: agregarlo con `fop=/opt/guarani/php/3ros/fop/fop`.
- Verificar que `/opt/guarani/php/3ros/fop/fop` sea ejecutable.

## Caracteres raros (acentos)

La base debe estar en LATIN1. Verificar:

```bash
docker compose exec db psql -U "$POSTGRES_USER" -d guarani3 \
  -tAc "show server_encoding; show client_encoding; show bytea_output;"
```

Esperado: `LATIN1`, `LATIN1`, `escape`. Si la base se creó en UTF8, hace falta
`./scripts/reset.sh` (el Dockerfile ya fija `POSTGRES_INITDB_ARGS` correctamente).

## El healthcheck queda `unhealthy` pero la web responde

```bash
docker compose exec gestion curl -s -o /dev/null -w "%{http_code}\n" http://localhost/guarani/3.23/
```

Si devuelve 200, el problema es del healthcheck (por ejemplo un cambio de puerto interno
o de alias). Reiniciar: `docker compose restart gestion`.

## La instalación se hizo pero no entra con `toba`/`toba`

```bash
docker compose exec db psql -U "$POSTGRES_USER" -d guarani3 \
  -tAc "select usuario, nombre from desarrollo.apex_usuario where usuario='toba'"
```

- Si no aparece el usuario, la instalación no terminó: ver
  `/var/log/guarani/entrypoint.log`.
- Si aparece pero la clave no funciona, se cambió `TOBA_PASSWORD` después de instalar.
  Opción 1: restaurar el valor original en `.env` y reinstalar (`reset.sh`).
  Opción 2: cambiar la clave desde el editor (`/toba_editor/3.4`).

## Reconstruir sin perder datos

```bash
docker compose up -d --build gestion
docker compose ps
```

No hace falta `down -v`: los volúmenes se conservan y el entrypoint detecta la marca
`.docker-instalado`, por lo que **no vuelve a instalar**.

## Autogestión (3w)

### La página de 3w muestra "Tiene que setear ... 'url_identidad_genero'" o "'email_ayuda'"

El entrypoint agrega esos valores a `instalacion/config.php`. Si aparece el mensaje, el
marcador `.docker-configurado` está viejo. Forzar la reconfiguración:

```bash
docker compose exec autogestion rm -f /opt/guarani-3w/instalacion/.docker-configurado
docker compose restart autogestion
```

### "password authentication failed" en 3w

El script oficial `docker-instalar` usa `sed` para reemplazar la clave en `config.php`;
si la clave tiene `&`, `#` o `\`, el reemplazo se rompe. El entrypoint la reescribe desde
la variable de entorno. Verificar:

```bash
docker compose exec autogestion grep -n 'pdo_passwd' /opt/guarani-3w/instalacion/config.php
docker compose exec -T autogestion sh -c 'cd /opt/guarani-3w/bin && ./guarani test_conexion des01'
```

### 3w no levanta: `ext-intl` faltante

La imagen `Dockerfile.3w` ya instala `libicu-dev` + `intl`. Si se construyó una imagen
propia, verificar:

```bash
docker compose exec autogestion php -m | grep -i intl
```

### "La unidad académica no existe" o no se puede loguear

`AUTOGESTION_UA` debe ser el id de una unidad académica real de Gestión
(`negocio.sga_unidades_gestion`). El default `5` viene del template de SIU.
Además hay que crear una persona con usuario/clave en Guaraní: el usuario `toba` no sirve
para 3w. Ver [3W.md](3W.md).

### Dos alias duplicados en Apache

El script oficial crea `guarani-autogestion.conf` y el entrypoint crea
`autogestion.conf`. El entrypoint ya elimina el primero. Si hay warnings `AH00671`:

```bash
docker compose exec autogestion sh -c \
  'rm -f /etc/apache2/sites-enabled/guarani-autogestion.conf && ln -sfn /opt/guarani-3w/instalacion/alias.conf /etc/apache2/sites-enabled/autogestion.conf'
docker compose restart autogestion
```

## Diagnóstico general

```bash
docker compose ps
docker compose logs --tail=200 gestion
docker compose exec gestion sh -c 'tail -100 /var/log/guarani/entrypoint.log'
docker compose exec gestion sh -c 'php -v && php -m | grep -Ei "pgsql|gd|zip|apcu|curl|mbstring|exif"'
docker compose exec db psql -U "$POSTGRES_USER" -d guarani3 -c '\dn'
```
