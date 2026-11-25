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

## Volúmenes y persistencia

| Volumen | Contenido |
|---|---|
| `guarani_pgdata` | datos de PostgreSQL |
| `guarani_instalacion` | configuración Toba (`instalacion.ini`, `toba.conf`, `i__desarrollo`) |
| `guarani_www` | recursos navegables generados por Toba |
| `guarani_temp` | temporales de la aplicación |
| `guarani_metadatos` | metadatos compilados |
| `guarani_fw_www`, `guarani_fw_temp` | recursos y temporales del framework |

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
docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d guarani3 -Fc \
  > backups/guarani3_$(date +%F).dump

# Opcional: copiar la configuración Toba
docker run --rm -v guarani_guarani_instalacion:/data -v "$PWD/backups:/out" \
  alpine tar czf /out/instalacion_$(date +%F).tar.gz -C /data .
```

### Restore

```bash
docker compose down
docker compose up -d db
docker compose exec -T db pg_restore -U "$POSTGRES_USER" -d guarani3 --clean \
  < backups/guarani3_YYYY-MM-DD.dump
docker compose up -d gestion
```

Si también restaurás `instalacion`, extraérlo dentro del volumen:

```bash
docker run --rm -v guarani_guarani_instalacion:/data -v "$PWD/backups:/in" \
  alpine sh -c 'tar xzf /in/instalacion_YYYY-MM-DD.tar.gz -C /data'
```

## Actualizar el código

El código fuente vive en `./src` (checkout SVN) y se copia a la imagen en el build.

```bash
# Actualizar el checkout en el host
docker run --rm -e SVN_USER -e SVN_PASSWORD -v "$PWD/src:/work" -w /work alpine:3.20 \
  sh -c 'apk add --no-cache subversion >/dev/null && \
         svn cleanup --username "$SVN_USER" --password "$SVN_PASSWORD" /work && \
         svn update --non-interactive --username "$SVN_USER" --password "$SVN_PASSWORD" /work'

# Reconstruir y recrear el contenedor (la base se conserva)
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

Elimina **todos los volúmenes** (incluida la base de datos) y vuelve a instalar.
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
