# Preinscripción 3.23.0

Módulo de Preinscripción integrado siguiendo la
[guía oficial de instalación desde cero](https://documentacion.siu.edu.ar/wiki/SIU-Guarani/preinscripcion3.23.0/instalacion_desde_cero/instalacion).

## Cómo se integró

| Paso de la documentación | Cómo quedó en el compose |
|---|---|
| Checkout de `nodos/iupa/preinscripcion/trunk/3.23.0` | `scripts/04-svn-checkout-preinscripcion.sh` → `./src-preinscripcion` |
| Permisos de `instalacion/temp`, `log`, `cache` y `src/siu/www` | entrypoint (`www-data` + `g+rwX`) e imagen |
| `composer install` | `Dockerfile.preinscripcion` (PHP 8.1 + Composer 2 + `intl`) |
| Crear base `preinscripcion` en LATIN1 | `docker/db-init/01-create-preinscripcion.sql` + entrypoint (si el volumen ya existía) |
| Cargar `BD/creacion/creacion_preinscripcion3_postgresql.sql` | entrypoint, solo si no existe `admin_usuarios` |
| `alias.conf` desde `alias_template.conf` | entrypoint + `docker/configure-preinscripcion.php` |
| `login.php` desde `login_template.php` | entrypoint |
| `./preinscripcion user_admin` | entrypoint (idempotente, usuario configurable) |
| `config.php` desde `config_template.php` | entrypoint: conecta a `preinscripcion` y a `guarani3`/`negocio` |

La imagen usa la extensión **`intl`** por la misma razón que 3w (`laminas/laminas-i18n`).

## Base de datos

Preinscripción tiene **su propia base** `preinscripcion` (LATIN1, `template0`, locale `C`)
dentro del mismo contenedor `postgres:14`. El esquema cargado es el oficial 3.23.0
(`app_versiones_base` queda en `3.23.0`, no hacen falta migraciones).

`config.php` deja dos conexiones por punto de acceso:

- `database` → base `preinscripcion` (dueña de las inscripciones).
- `database_guarani` → base `guarani3`, esquema `negocio` (consulta de propuestas, personas, parámetros).

## Puntos de acceso y URLs

Con `PREINSCRIPCION_PTO=iupa` (configurable) se generan:

| Perfil | URL |
|---|---|
| Alumno | http://localhost:8092/preinscripcion/iupa |
| Administrador | http://localhost:8092/preinscripcion_admin/iupa |

`alias.conf` define `ID_PTO_ACCESO` y `PERFIL` (`alumno` / `admin`) para cada `<Location>`,
y el usuario admin se crea con ese mismo id de punto de acceso.

## Variables nuevas en `.env`

| Variable | Default | Uso |
|---|---|---|
| `PREINSCRIPCION_PORT` | `8092` | Puerto HTTP del módulo |
| `PREINSCRIPCION_PTO` | `iupa` | Segmento del alias e `ID_PTO_ACCESO` |
| `PREINSCRIPCION_ADMIN_USER` | `admin` | Usuario administrador |
| `PREINSCRIPCION_ADMIN_PASSWORD` | `admin123` | Clave del administrador |

El captcha se desactiva porque no hay keys de reCAPTCHA en el entorno local.
`email_ayuda` se toma de `AUTOGESTION_EMAIL_AYUDA`.

## Verificación

```bash
docker compose ps          # los 4 servicios healthy
docker compose exec -T db psql -U "$POSTGRES_USER" -d preinscripcion \
  -c "select version_base from app_versiones_base;"
docker compose exec -T db psql -U "$POSTGRES_USER" -d preinscripcion \
  -c "select usuario, id_pto_acceso from admin_usuarios;"

curl -Ls -o /dev/null -w "%{http_code}\n" http://localhost:8092/preinscripcion_admin/iupa/  # 200 (login)
```

La pantalla de **alumno** puede mostrar una página de error mientras no se configuren los
parámetros de preinscripción y los turnos desde Gestión: es el paso 1.8.2 de la guía oficial,
que requiere intervención en la interfaz (no se automatiza).

## Configuración pendiente desde Gestión

Según la documentación oficial, en Gestión hay que configurar:

- los parámetros del sistema correspondientes a **Pre Inscripción**;
- los **turnos de presentación de documentación**;
- los perfiles de datos de cada punto de acceso desde el panel de administración de
  Preinscripción (`/preinscripcion_admin/iupa`).

## Producción

```bash
docker compose exec preinscripcion \
  sh -c 'cd /opt/preinscripcion/bin && ./preinscripcion compilar_recursos'
```

Luego activar `'produccion' => true` en `instalacion/config.php` (el archivo vive en el
volumen `guarani_preinscripcion_instalacion`, por lo que el cambio persiste).

## Persistencia

Los archivos generados están en el volumen `guarani_preinscripcion_instalacion`; la base,
en `guarani_pgdata`. `docker compose down` no los borra. `scripts/reset.sh` (`down -v`) sí:
al recrear, el init de PostgreSQL vuelve a crear `preinscripcion` y el entrypoint recarga
el esquema y el usuario admin.
