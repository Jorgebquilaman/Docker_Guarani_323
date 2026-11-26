# Arquitectura

## Servicios

```
                         host
     ┌────────┬────────┬────────┬────────┬────────┬────────┐
     │ :8090  │ :8091  │ :8092  │ :8093  │ :8094  │ :5434  │
     └───┬────┴───┬────┴───┬────┴───┬────┴───┬────┴───┬────┘
         │        │        │        │        │        │
     ┌───▼───┐┌───▼───┐┌───▼────┐┌───▼───┐┌───▼────┐┌───▼─────────┐
     │gestión││  3w   ││preinscr││ kolla ││tehuelche││     db      │
     │PHP+JDK││PHP+intl││PHP+intl││PHP+xsl││PHP+xsl ││ PostgreSQL14│
     │Jasper ││Chulupi ││base    ││yarn   ││yarn    ││ 4 bases     │
     └───┬───┘└───┬───┘└───┬────┘└───┬───┘└───┬────┘└───┬─────────┘
         │        │        │         │         │          │
         └────────── red interna: guarani_default ─────────────────┘
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
- **`kolla`**: imagen desde `Dockerfile.kolla`, construida del RAR `instalador_kolla_4.10.3.rar`.
  Base propia `kolla`, usuario de BD dedicado, PHP con `xsl`, `intl`, `svn` y Yarn para los
  assets. Publica `/kolla` en el puerto 8093. Ver [KOLLA.md](KOLLA.md).
- **`tehuelche`**: imagen desde `Dockerfile.tehuelche`, construida del RAR
  `instalador_tehuelche_4.5.2.rar`. Base propia `tehuelche`, usuario de BD dedicado y
  esquemas `desarrollo`, `tehuelche`, `referencia`. Publica `/tehuelche` en 8094.
  Ver [TEHUELCHE.md](TEHUELCHE.md).

## Imágenes

Todas parten de `php:8.1-apache-bookworm` (arm64/amd64) e instalan `pgsql`, `pdo_pgsql`,
`gd`, `zip`, `exif`, `bcmath`, `opcache` y `apcu`, además de Composer 2 y `postgresql-client`.

| Dockerfile | Módulo | Extra |
|---|---|---|
| `Dockerfile` | Gestión | `default-jre-headless`, JavaBridge Jasper, `graphviz` |
| `Dockerfile.3w` | Autogestión | `intl` (Chulupi) |
| `Dockerfile.preinscripcion` | Preinscripción | `intl` (Chulupi) |
| `Dockerfile.kolla` | Kolla | `intl`, `xsl`, `svn`, `nodejs`/`yarn`, `iconv`, scripts de assets |
| `Dockerfile.tehuelche` | Tehuelche | igual que Kolla |

Las dependencias PHP están fijadas por los `composer.lock` de cada proyecto
(Gestión usa `siu-toba/framework` v3.4.3; Kolla y Tehuelche traen el suyo).
Kolla y Tehuelche convierten sus SQL UTF-8 a LATIN1 durante el build.

## Flujo del entrypoint

Cada `docker/entrypoint*.sh` sigue el mismo esquema: esperar PostgreSQL → asegurar base y
permisos → instalar si no existe el marcador `.docker-instalado` → linkear `toba.conf` o
`alias.conf` → `apachectl configtest` → `apache2-foreground`.

Particularidades:

- **Gestión**: procedimiento documentado con `toba instalacion instalar`, `guarani cargar -d`,
  `guarani instalar` (sin `-j`) y `crear_auditoria`. Respaldo con `bin/instalador`.
  Configura `menu=2`, `fop` y arranca el JavaBridge en `8081`.
- **3w**: usa `bin/docker-instalar` del repo y reescribe `config.php` con PHP (la clave tiene
  caracteres que rompen `sed`). Reutiliza el JavaBridge de Gestión.
- **Preinscripción**: crea la base, carga `BD/creacion/creacion_preinscripcion3_postgresql.sql`
  y genera el usuario admin con `./preinscripcion user_admin`.
- **Kolla y Tehuelche**: instalan en `instalacion.tmp` (el instalador rechaza el directorio
  del volumen), copian el resultado, corrigen las rutas absolutas y todo se guarda en el
  volumen. En Kolla se agrega además la `RewriteRule ^responder` de habilitaciones públicas.

### Detalle: Gestión

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
| `/preinscripcion/iupa`, `/preinscripcion_admin/iupa` | Preinscripción (alumno/admin) |
| `/kolla`, `/kolla/toba` | Kolla y su núcleo Toba |
| `/tehuelche`, `/tehuelche/toba` | Tehuelche y su núcleo Toba |

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
| Usuario de BD propio para Kolla | Toba arma comandos shell con la clave; los caracteres especiales los rompen |
| `iconv` de SQL a LATIN1 en el build de Kolla/Tehuelche | algunos SQL vienen en UTF-8 y la base es LATIN1 |
| Usuario de BD propio para Tehuelche | misma razón que Kolla: claves con caracteres especiales rompen comandos Toba |
| Instalación en `instalacion.tmp` | el instalador rechaza directorios de instalación existentes (el volumen siempre existe) |

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
├── Dockerfile.kolla
├── Dockerfile.tehuelche
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
│   ├── 05-extraer-kolla.sh
│   ├── 06-extraer-tehuelche.sh
│   └── reset.sh
├── docs/                 # esta documentación
├── src/                  # checkout SVN de Gestión (NO versionar)
├── src-3w/               # checkout SVN de 3w (NO versionar)
├── src-preinscripcion/   # checkout SVN de Preinscripción (NO versionar)
├── src-kolla/            # contenido del RAR de Kolla (NO versionar)
└── src-tehuelche/        # contenido del RAR de Tehuelche (NO versionar)
```
