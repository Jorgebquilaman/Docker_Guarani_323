# Arquitectura

## Servicios

```
                         host
     ┌──────────┬──────────┬──────────┬──────────┐
     │ :8090    │ :8091    │ :8092    │ :5434    │
     └────┬─────┴────┬─────┴────┬─────┴────┬─────┘
          │          │          │          │
     ┌────▼────┐┌────▼────┐┌────▼────────┐┌───▼──────────┐
     │ gestion ││ 3w      ││preinscripcion││    db        │
     │ PHP+JDK ││ PHP+intl││ PHP+intl    ││ PostgreSQL14 │
     │ Jasper  ││ Chulupi ││ base propia ││ 2 bases      │
     └────┬────┘└────┬────┘└────┬────────┘└───┬──────────┘
          │          │          │              │
          └───────── red interna: guarani_default ────────┘
```

- **`db`**: `postgres:14-bookworm`. Base `guarani3`, encoding `LATIN1`, locale `C`,
  `bytea_output=escape`, zona horaria `America/Argentina/Buenos_Aires`. Healthcheck con
  `pg_isready`.
- **`gestion`**: imagen construida desde el `Dockerfile`. Apache sirve PHP 8.1; dentro del
  mismo contenedor corre el JavaBridge de Jasper (puerto 8081, no publicado).
- **`autogestion`**: imagen construida desde `Dockerfile.3w`. Apache + PHP 8.1 con la
  extensión `intl` (la exige `laminas/laminas-i18n`), Composer y el framework Chulupi.
  Usa la misma base `guarani3` (schemas `negocio`/`desarrollo`) y el JavaBridge de
  `gestion`. Publica `/3w` en el puerto 8091. Ver [3W.md](3W.md).
- **`preinscripcion`**: imagen desde `Dockerfile.preinscripcion`. Tiene su **propia base**
  `preinscripcion` en el mismo PostgreSQL, con dos alias (`/preinscripcion/iupa` y
  `/preinscripcion_admin/iupa`) en el puerto 8092. Ver [PREINSCRIPCION.md](PREINSCRIPCION.md).

## Imagen

- Base: `php:8.1-apache-bookworm` (arm64/amd64).
- Paquetes: `git`, `subversion`, `unzip`, `zip`, `curl`, `libpq-dev`, `libpng-dev`,
  `libjpeg-dev`, `libfreetype-dev`, `libzip-dev`, `default-jre-headless`, `graphviz`,
  fuentes, `postgresql-client`, `cron`.
- Extensiones PHP: `pgsql`, `pdo_pgsql`, `gd`, `zip`, `exif`, `bcmath`, `opcache`, `apcu`.
- Composer 2 copiado desde la imagen oficial; dependencias fijadas por `composer.lock`
  (framework `siu-toba/framework` v3.4.3, `siu-toba/jasper` v5.6.1.2, etc.).
- Capas: primero `composer.json`/`composer.lock` (caché de dependencias), después el resto
  del código, y por último los scripts de compatibilidad del proyecto.

## Flujo del entrypoint

1. Espera a que PostgreSQL acepte conexiones.
2. Si no existe `instalacion/.docker-instalado`:
   1. Genera `instalador.env` con los valores de `.env` (host, puerto, usuario, clave,
      schemas `desarrollo`/`negocio`, encoding LATIN1, alias y URL base).
   2. Ejecuta el procedimiento documentado:
      - `vendor/siu-toba/framework/bin/toba instalacion instalar` con respuestas no
        interactivas (alias `toba_guarani3`, desarrollador 0, entorno desarrollo, nombre
        `guarani3`, datos de DB y clave Toba).
      - `bin/guarani cargar -d /opt/guarani` (responde `s` al alias de Apache).
      - `bin/guarani instalar` (sin `-j`: **sin datos de prueba**).
      - `bin/guarani crear_auditoria -f guarani`.
   3. Como respaldo, si el procedimiento anterior falla, prueba
      `bin/instalador proyecto:instalar --no-interaction ...`. En 3.23.0 ese instalador
      falla si todavía no existe la instancia Toba; por eso no es el método principal.
   4. Ajusta permisos `www-data` en las carpetas navegables/temporales/de configuración.
   5. Crea el marcador de instalación.
3. Configuraciones idempotentes (también en reinicios):
   - `menu.ini` → `menu=2` (la plantilla trae `menu = #`, valor inválido).
   - `[xslfo] fop=...` al final de `instalacion/instalacion.ini`.
4. Habilita `instalacion/toba.conf` como sitio de Apache y corre `apachectl configtest`.
5. Arranca JavaBridge Jasper en segundo plano y ejecuta `apache2-foreground` como PID 1.

## Alias generados por Toba

| Alias | Destino |
|---|---|
| `/guarani/3.23` | gestión (`www/`) |
| `/guarani_pers/3.23` | personalizaciones (`personalizacion/www/`) |
| `/toba_editor/3.4` | editor de Toba |
| `/toba_referencia/3.4` | referencia de Toba |
| `/toba_usuarios/3.4` | administración de usuarios |
| `/toba_guarani3` | núcleo del framework |
| `/3w` (contenedor `autogestion`) | autogestión (`src/siu/www`) |

## Decisiones de configuración

| Decisión | Motivo |
|---|---|
| PHP 8.1 | Requerido por `composer.json` de Guaraní 3.23.0 |
| PostgreSQL 14 | Versión indicada en los requisitos previos de 3.23 |
| LATIN1 / locale C | Los `.dca`/`.sql` del repositorio están en ISO-8859-1 y es el default del instalador SIU |
| `bytea_output=escape` | Requerido por la documentación oficial |
| Sin datos de prueba | Pedido del usuario: solo esquema y datos básicos del sistema |
| Puerto 8090 | 8080 estaba ocupado por otro contenedor en el equipo original |
| Volúmenes separados | Permiten reconstruir la imagen sin perder la instalación ni la base |
| `menu=2` | La plantilla del SVN tiene un valor inválido que rompe la pantalla de login |
| 3w como servicio separado | Usa el mismo `db` pero su propio Apache y configuración (`config.php`) |
| `intl` en la imagen 3w | Lo exige `laminas/laminas-i18n` (dependencia de Chulupi) |
| Jasper compartido | 3w apunta a `gestion:8081`; evita un segundo JavaBridge |
| Base propia para Preinscripción | La documentación oficial exige base LATIN1 separada; se crea en el init de PostgreSQL |
| `str_replace` en PHP para `config.php` | Evita que claves con `&`, `#` o `\` se rompan con `sed` |

## Archivos del repositorio

```
.
├── .env                  # credenciales (NO versionar)
├── .env.example          # plantilla sin secretos
├── .gitignore
├── .dockerignore         # excluye src/.svn y src-3w/.svn del contexto de build
├── docker-compose.yml
├── Dockerfile            # Gestión
├── Dockerfile.3w         # Autogestión
├── Dockerfile.preinscripcion
├── docker/
│   ├── entrypoint.sh
│   ├── entrypoint-3w.sh
│   ├── entrypoint-preinscripcion.sh
│   ├── configure-preinscripcion.php
│   ├── db-init/          # crea la base preinscripcion
│   └── php/guarani.ini
├── scripts/
│   ├── 01-svn-checkout.sh
│   ├── 02-up.sh
│   ├── 03-svn-checkout-3w.sh
│   ├── 04-svn-checkout-preinscripcion.sh
│   └── reset.sh
├── docs/                 # esta documentación
├── src/                  # checkout SVN de Gestión (NO versionar)
├── src-3w/               # checkout SVN de 3w (NO versionar)
└── src-preinscripcion/   # checkout SVN de Preinscripción (NO versionar)
```
