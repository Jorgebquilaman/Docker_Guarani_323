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
lsof -nP -iTCP -sTCP:LISTEN | grep -E ':(8090|8091|8092|8093|8094|5434)\b'
```

```dotenv
GESTION_PORT=8095        # Gestión
W3_PORT=8096             # Autogestión
PREINSCRIPCION_PORT=8097
KOLLA_PORT=8098
TEHUELCHE_PORT=8099
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

## La instalación se hizo pero no entra con el usuario admin

Cada módulo tiene su propio usuario/clave:

| Módulo | Usuario | Clave |
|---|---|---|
| Gestión y editor | `toba` | `TOBA_PASSWORD` (`toba` por defecto) |
| Kolla | `toba` | `KOLLA_PASSWORD` |
| Tehuelche | `toba` | `TEHUELCHE_PASSWORD` |
| Preinscripción admin | `PREINSCRIPCION_ADMIN_USER` | `PREINSCRIPCION_ADMIN_PASSWORD` |
| 3w | persona de Guaraní | la de esa persona |

```bash
docker compose exec db psql -U "$POSTGRES_USER" -d guarani3 \
  -tAc "select usuario, nombre from desarrollo.apex_usuario where usuario='toba'"
docker compose exec db psql -U kolla -d kolla \
  -tAc "select usuario from desarrollo.apex_usuario where usuario='toba'"
docker compose exec db psql -U tehuelche -d tehuelche \
  -tAc "select usuario from desarrollo.apex_usuario where usuario='toba'"
```

- Si no aparece el usuario, la instalación no terminó: ver el `entrypoint.log` de ese módulo.
- Si aparece pero la clave no funciona, se cambió la variable en `.env` después de instalar.
  Restaurar el valor original y reinstalar (`reset.sh`) o cambiar la clave desde la interfaz.

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

## Preinscripción

### El panel de alumnos muestra una página de error

Es esperable con la base recién creada: hay que configurar los parámetros de
**Pre Inscripción** y los turnos de presentación de documentación desde Gestión, y los
perfiles de datos desde el panel admin. Ver
[PREINSCRIPCION.md → Configuración pendiente desde Gestión](PREINSCRIPCION.md#configuración-pendiente-desde-gestión).

### No existe la base `preinscripcion`

El entrypoint la crea (LATIN1) si falta; en una instalación nueva también la crea el script
`docker/db-init/01-create-preinscripcion.sql`. Verificar:

```bash
docker compose exec -T db psql -U "$POSTGRES_USER" -d postgres \
  -c "select datname, pg_encoding_to_char(encoding) from pg_database where datname='preinscripcion'"
```

### `config.php` todavía tiene placeholders

Si aparece `nombre_base_preinscripcion` o `[id_pto_acc]` en la configuración, forzar la
regeneración:

```bash
docker compose exec preinscripcion rm -f /opt/preinscripcion/instalacion/.docker-instalado
docker compose restart preinscripcion
```

El archivo se vuelve a generar desde la plantilla con los valores de `.env`.

### El healthcheck de `preinscripcion` queda unhealthy

Debe apuntar a `/preinscripcion/<PREINSCRIPCION_PTO>/` (no a `/preinscripcion/`).
Comprobar con `curl -Ls -o /dev/null -w '%{http_code}' http://localhost:8092/preinscripcion/iupa/`.

## Kolla

### Falta el RAR o `src-kolla/`

Kolla no se baja por SVN: hay que poner `instalador_kolla_4.10.3.rar` en la raíz y correr
`./scripts/05-extraer-kolla.sh`. El RAR está ignorado por Git.

### Error `value too long for type character varying(30)` al instalar

Los SQL del RAR mezclan codificaciones: `db/estructura.sql` es UTF-8 y la base es LATIN1.
El `Dockerfile.kolla` convierte todos los SQL UTF-8 a LATIN1 con `iconv` durante el build.
Si se construyó una imagen propia, verificar:

```bash
docker compose exec kolla file -b -I /opt/kolla/db/estructura.sql   # iso-8859-1
```

### Falta `apex_proyecto` o `apex_puntos_montaje`

La metadata Toba no se cargó. Reiniciar la instalación desde cero:

```bash
docker compose stop kolla
docker compose exec -T db psql -U sarnal -d postgres -c 'DROP DATABASE IF EXISTS kolla'
docker compose exec -T db psql -U sarnal -d postgres -c "CREATE DATABASE kolla OWNER kolla ENCODING 'LATIN1' TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C'"
docker run --rm -v guarani_guarani_kolla_instalacion:/data alpine sh -c 'rm -rf /data/* /data/.[!.]* 2>/dev/null || true'
docker compose up -d --build kolla
```

### CSS/JS 404 en `/kolla/toba/...`

Faltan los assets de Yarn. El build ejecuta los `post-install-cmd` del framework y de
`manejador-salida-bootstrap`; verificar que `nodejs`, `yarn` y esos scripts estén en el
`Dockerfile.kolla`, y reconstruir la imagen.

### Clave del admin muy corta

El instalador exige al menos 8 caracteres para `KOLLA_PASSWORD`. Usar por defecto
`toba123*-a` (configurable en `.env`).

## Tehuelche

### Falta el RAR o `src-tehuelche/`

Poner `instalador_tehuelche_4.5.2.rar` en la raíz y ejecutar
`./scripts/06-extraer-tehuelche.sh`. El RAR y `src-tehuelche/` están ignorados por Git.

### El instalador dice que ya existe una instalación

El volumen `instalacion/` existe vacío y Toba lo rechaza. El entrypoint instala en
`instalacion.tmp` y copia el resultado, igual que el script oficial `docker/bin/crear-bd.sh`.
Si quedó un `.docker-instalado` viejo, limpiar:

```bash
docker run --rm -v guarani_tehuelche_instalacion:/data alpine sh -c 'rm -rf /data/* /data/.[!.]* 2>/dev/null || true'
docker compose restart tehuelche
```

### Error de encoding al cargar SQL

La base es LATIN1 y algunos SQL del RAR son UTF-8. El build los convierte con `iconv`.
Verificar:

```bash
docker compose exec tehuelche sh -c "file -b -I /opt/tehuelche/sql/migraciones/4.1.0/nuevas_tablas.sql"
```

### CSS/JS 404 en `/tehuelche/toba/...`

Faltan los assets de Yarn. El build ejecuta los `post-install-cmd` del framework y de
`manejador-salida-bootstrap`; reconstruir la imagen si faltan.

### Las propuestas no aparecen

El paso 11 de la guía oficial requiere vincular Tehuelche con Guaraní e importar las
propuestas desde **Administración → Sincronizar Propuestas**. Ver
[TEHUELCHE.md → Integración con Guaraní](TEHUELCHE.md#integración-con-guaraní-paso-11-de-la-guía).

## Diagnóstico general

```bash
docker compose ps
docker compose logs --tail=200 gestion
docker compose exec gestion sh -c 'tail -100 /var/log/guarani/entrypoint.log'
docker compose exec gestion sh -c 'php -v && php -m | grep -Ei "pgsql|gd|zip|apcu|curl|mbstring|exif"'
docker compose exec db psql -U "$POSTGRES_USER" -d guarani3 -c '\dn'
```
