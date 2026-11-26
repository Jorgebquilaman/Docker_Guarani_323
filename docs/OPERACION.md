# Operación y mantenimiento

## Comandos diarios

```bash
docker compose up -d                 # levantar (sin reconstruir)
docker compose down                  # detener (conserva datos y volúmenes)
docker compose restart gestion       # reiniciar solo la aplicación
docker compose ps                    # estado y puertos
docker compose logs -f gestion       # logs de Apache + instalación + JavaBridge
docker compose logs -f db            # logs de PostgreSQL
docker compose exec gestion bash     # shell dentro del contenedor
docker compose exec db bash          # shell de la base
```

## Logs dentro del contenedor `gestion`

| Archivo | Contenido |
|---|---|
| `/var/log/guarani/entrypoint.log` | estructura de arranque, instalación y Apache |
| `/var/log/guarani/javabridge.log` | arranque del puente Java de Jasper |
| `/opt/guarani/instalador.log` | detalle del instalador de SIU (si se generó) |
| salida estándar de Apache | errores PHP y requests HTTP |

Ejemplo:

```bash
docker compose exec gestion tail -50 /var/log/guarani/entrypoint.log
docker compose exec gestion tail -30 /var/log/guarani/javabridge.log
```

### Autogestión (3w)

```bash
docker compose logs -f autogestion
docker compose exec autogestion tail -50 /var/log/guarani-3w/entrypoint.log
docker compose exec autogestion sh -c 'cd /opt/guarani-3w/bin && ./guarani test_conexion des01'
```

3w reutiliza el JavaBridge de Gestión (`gestion:8081`): no hace falta iniciar otro.
Ver [3W.md](3W.md) para los parámetros `AUTOGESTION_*`.

### Preinscripción

```bash
docker compose logs -f preinscripcion
docker compose exec preinscripcion tail -50 /var/log/preinscripcion/entrypoint.log
docker compose exec -T db psql -U "$POSTGRES_USER" -d preinscripcion \
  -c "select version_base from app_versiones_base"
```

Ver [PREINSCRIPCION.md](PREINSCRIPCION.md) para los parámetros `PREINSCRIPCION_*`.

### Kolla

```bash
docker compose logs -f kolla
docker compose exec kolla tail -50 /var/log/kolla/entrypoint.log
docker compose exec -T db psql -U kolla -d kolla \
  -c "select table_schema, count(*) from information_schema.tables where table_schema in ('desarrollo','kolla') group by 1"
```

Ver [KOLLA.md](KOLLA.md). Para backup de Kolla hay que incluir la base `kolla` además de
`guarani3` y `preinscripcion`.

### Tehuelche

```bash
docker compose logs -f tehuelche
docker compose exec tehuelche tail -50 /var/log/tehuelche/entrypoint.log
docker compose exec -T db psql -U tehuelche -d tehuelche \
  -c "select table_schema, count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema') group by 1"
```

Ver [TEHUELCHE.md](TEHUELCHE.md). El backup debe incluir también la base `tehuelche`.

## Volúmenes y persistencia

| Volumen | Contenido |
|---|---|
| `guarani_pgdata` | datos de PostgreSQL |
| `guarani_instalacion` | configuración Toba (`instalacion.ini`, `toba.conf`, `i__desarrollo`) |
| `guarani_www` | recursos navegables generados por Toba |
| `guarani_temp` | temporales de la aplicación |
| `guarani_metadatos` | metadatos compilados |
| `guarani_fw_www`, `guarani_fw_temp` | recursos y temporales del framework |
| `guarani_3w_instalacion` | `config.php`, `alias.conf`, `login.php` y logs de Autogestión |
| `guarani_preinscripcion_instalacion` | `config.php`, `alias.conf`, `login.php` y logs de Preinscripción |
| `guarani_kolla_instalacion` | `instalacion.ini`, `bases.ini`, `toba.conf` y logs de Kolla |
| `guarani_tehuelche_instalacion` | `instalacion.ini`, `bases.ini`, `toba.conf` y logs de Tehuelche |

Apagar los contenedores, reiniciar Docker Desktop o reconstruir la imagen (`up --build`)
**no borra** los datos: todo lo que los cinco módulos necesitan para funcionar está en los volúmenes.
Solo se pierde lo que hayas modificado a mano dentro del contenedor fuera de esos volúmenes
(por ejemplo, código fuente o `menu.ini` editado directamente).

`docker compose down` **no borra** estos volúmenes. Para verlos:

```bash
docker volume ls | grep guarani
docker volume inspect guarani_guarani_pgdata
```

La instalación se marca con `/opt/guarani/instalacion/.docker-instalado`. Si el archivo
existe, el entrypoint no vuelve a instalar; por eso reiniciar o reconstruir la imagen es seguro.

## Backup y restore

### Backup

```bash
mkdir -p backups
FECHA=$(date +%F)

# Las cuatro bases (USER/PASSWORD según corresponda)
for base in guarani3 preinscripcion; do
  docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "$base" -Fc \
    > "backups/${base}_${FECHA}.dump"
done
docker compose exec -T db pg_dump -U "${KOLLA_DB_USER:-kolla}" -d kolla -Fc \
  > "backups/kolla_${FECHA}.dump"
docker compose exec -T db pg_dump -U "${TEHUELCHE_DB_USER:-tehuelche}" -d tehuelche -Fc \
  > "backups/tehuelche_${FECHA}.dump"

# Configuración de Toba de cada módulo
for volumen in guarani_instalacion guarani_3w_instalacion \
               guarani_preinscripcion_instalacion guarani_kolla_instalacion \
               guarani_tehuelche_instalacion; do
  docker run --rm -v "${volumen}:/data" -v "$PWD/backups:/out" \
    alpine tar czf "/out/${volumen}_${FECHA}.tar.gz" -C /data .
done
```

### Restore

```bash
docker compose down
docker compose up -d db
for base in guarani3 preinscripcion; do
  docker compose exec -T db pg_restore -U "$POSTGRES_USER" -d "$base" --clean \
    < "backups/${base}_YYYY-MM-DD.dump"
done
docker compose exec -T db pg_restore -U kolla -d kolla --clean \
  < backups/kolla_YYYY-MM-DD.dump
docker compose exec -T db pg_restore -U tehuelche -d tehuelche --clean \
  < backups/tehuelche_YYYY-MM-DD.dump
docker compose up -d
```

Si también restaurás la configuración de un módulo, extraer el tar dentro de su volumen:

```bash
docker run --rm -v guarani_instalacion:/data -v "$PWD/backups:/in" \
  alpine sh -c 'tar xzf /in/guarani_instalacion_YYYY-MM-DD.tar.gz -C /data'
```

## Actualizar el código

Hay tres checkouts SVN (`src`, `src-3w`, `src-preinscripcion`) y dos códigos extraídos de
RAR (`src-kolla`, `src-tehuelche`). Todos se copian a su imagen en el build.

```bash
# Actualizar los checkouts SVN (reemplazar src por src-3w o src-preinscripcion)
docker run --rm -e SVN_USER -e SVN_PASSWORD -v "$PWD/src:/work" -w /work alpine:3.20 \
  sh -c 'apk add --no-cache subversion >/dev/null && \
         svn cleanup --username "$SVN_USER" --password "$SVN_PASSWORD" /work && \
         svn update --non-interactive --username "$SVN_USER" --password "$SVN_PASSWORD" /work'

# Para Kolla/Tehuelche: reemplazar el RAR en la raíz, borrar src-kolla / src-tehuelche
# y volver a ejecutar scripts/05-extraer-kolla.sh / scripts/06-extraer-tehuelche.sh

# Reconstruir y recrear los contenedores (las bases se conservan)
./scripts/02-up.sh
```

Si la versión nueva cambia la estructura de metadatos o de esquema, hace falta una
reinstalación completa: ver [Reinstalar desde cero](#reinstalar-desde-cero).

> Para pasar a otra versión (por ejemplo 3.24.x) hay que seguir la documentación oficial de
> **actualización** del SIU, no solo cambiar la URL del SVN.

## Reinstalar desde cero

```bash
./scripts/reset.sh
```

Elimina **todos los volúmenes** (las cuatro bases y las cinco configuraciones) y vuelve a instalar.
El script pide confirmación. Equivale a:

```bash
docker compose down -v
docker compose up -d --build
```

## Envío de emails (cron)

La documentación oficial recomienda ejecutar cada 10 minutos:

```bash
docker compose exec gestion /opt/guarani/bin/guarani enviar_emails_notificador
```

Para automatizarlo, agregar un cron en el host:

```cron
*/10 * * * * cd /ruta/al/proyecto && docker compose exec -T gestion /opt/guarani/bin/guarani enviar_emails_notificador >> logs/notificador.log 2>&1
```

Requiere tener configurado SMTP en `instalacion.ini` (sección `[smtp]`). Sin SMTP los
envíos fallarán, pero el resto del sistema funciona normalmente.

## API REST

El alias `/guarani/3.23/rest/` está activo (devuelve 302/`rest.php` sin credenciales).
Para usar la API hay que configurar los clientes OAuth y los permisos según la
[documentación oficial de API REST](https://documentacion.siu.edu.ar/wiki/SIU-Guarani/version3.23.0/interfaces/api-guarani-perfil-funcional).
No viene habilitada por defecto.

## Reportes Jasper

El puente Java corre dentro del contenedor en el puerto interno **8081**:

```bash
docker compose exec gestion sh -c 'pgrep -af php.java.bridge.Standalone'
docker compose exec gestion tail -30 /var/log/guarani/javabridge.log
```

La ruta de `fop` se agrega automáticamente a `instalacion/instalacion.ini`:

```ini
[xslfo]
fop=/opt/guarani/php/3ros/fop/fop
```
