# Instalación paso a paso

Esta guía permite levantar Guaraní Gestión en **cualquier equipo** (macOS, Linux o Windows
con WSL2) sin instalar PHP, Apache, PostgreSQL ni SVN en la máquina anfitriona: todo corre
dentro de Docker.

## 1. Requisitos

| Requisito | Detalle |
|---|---|
| Docker | Docker Desktop 24+ o Docker Engine con **Compose v2** (`docker compose version`) |
| Memoria | 8 GB de RAM o más recomendados (el VM de Docker necesita ~4 GB libres) |
| Disco | ~10 GB libres (código SVN ~1 GB, imagen ~2,3 GB, volúmenes y caché) |
| Red | Acceso a `colab.siu.edu.ar`, `satis.siu.edu.ar`, `api.github.com`, `deb.debian.org` y Docker Hub |
| Credenciales | Usuario/clave de **Colab** con acceso a `nodos/iupa` |

> Las imágenes base tienen variante **arm64** y **amd64**: funcionan tanto en Apple Silicon
> como en Intel/PC sin emulación.

### Credenciales de Colab

Si el usuario no tiene acceso al nodo `iupa`, debe solicitarlo mediante el
**Gestor de Solicitudes (GdS)** del SIU, como indica la documentación oficial. El checkout
usa autenticación **Digest**; un `401` casi siempre indica usuario/clave incorrectos o
falta de permisos sobre esa ruta.

## 2. Preparar el proyecto

```bash
git clone https://github.com/<tu-usuario>/<tu-repo>.git guarani
cd guarani

cp .env.example .env
```

Editar `.env` con un editor de texto:

```dotenv
SVN_URL=https://colab.siu.edu.ar/svn/guarani3/nodos/iupa/gestion/trunk/3.23.0
SVN_USER=tu_usuario_colab
SVN_PASSWORD='tu_clave_colab'

POSTGRES_DB=guarani3
POSTGRES_USER=tu_usuario_db
POSTGRES_PASSWORD='tu_clave_db'

GESTION_PORT=8090
W3_PORT=8091
DB_PORT_HOST=5434

AUTOGESTION_ALIAS=/3w
AUTOGESTION_UA=5
AUTOGESTION_EMAIL_AYUDA=soporte@example.edu.ar

PREINSCRIPCION_PORT=8092
PREINSCRIPCION_PTO=iupa
PREINSCRIPCION_ADMIN_USER=admin
PREINSCRIPCION_ADMIN_PASSWORD=cambiar-clave-admin

KOLLA_PORT=8093
KOLLA_ALIAS=/kolla
KOLLA_PASSWORD=toba123*-a
KOLLA_DB_USER=kolla
KOLLA_DB_PASSWORD=kolla123

TOBA_PASSWORD=toba
TOBA_SALT='semilla_aleatoria_larga'
```

**Reglas para los valores:**

- Usar **comillas simples** en las claves: la clave de ejemplo contiene `!`, `&`, `%` y `^`.
- `SVN_*`: credenciales reales de Colab (las mismas que se usan para el SVN).
- `POSTGRES_*`: usuario/clave de la base local del compose. Pueden ser los mismos valores.
- `GESTION_PORT`: puerto HTTP de Gestión. Cambiar si 8090 está ocupado.
- `W3_PORT`: puerto HTTP de Autogestión (3w). Cambiar si 8091 está ocupado.
- `DB_PORT_HOST`: puerto para conectarse a Postgres desde el host. Cambiar si 5434 está ocupado.
- `AUTOGESTION_*`: alias, unidad académica y email de ayuda del módulo 3w. Ver [3W.md](3W.md).
- `PREINSCRIPCION_*`: puerto, punto de acceso y usuario admin de Preinscripción. Ver [PREINSCRIPCION.md](PREINSCRIPCION.md).
- `KOLLA_*`: puerto, alias, clave del admin y usuario/clave de su base. Ver [KOLLA.md](KOLLA.md).
- `TOBA_PASSWORD`: clave del usuario administrador `toba` de Guaraní.
- `TOBA_SALT`: semilla interna; cambiar por una cadena aleatoria larga.

### Puertos

Verificar antes de empezar:

```bash
# macOS / Linux
lsof -nP -iTCP -sTCP:LISTEN | grep -E ':(8090|8091|8092|8093|5434)\b'

# Windows (WSL2)
netstat -ano | findstr ":8090 :8091 :8092 :8093 :5434"
```

Si hay conflicto, editar `GESTION_PORT`, `W3_PORT`, `PREINSCRIPCION_PORT`, `KOLLA_PORT` y
`DB_PORT_HOST` en `.env`. **No hace falta** tocar `docker-compose.yml`.

## 3. Descargar el código fuente

```bash
./scripts/01-svn-checkout.sh          # Gestión → ./src
./scripts/03-svn-checkout-3w.sh       # Autogestión (3w) → ./src-3w
./scripts/04-svn-checkout-preinscripcion.sh  # Preinscripción → ./src-preinscripcion

# Kolla: poner instalador_kolla_4.10.3.rar en la raíz del proyecto
./scripts/05-extraer-kolla.sh              # → ./src-kolla
```

Los scripts usan un contenedor `alpine` con `subversion`, por lo que **no hace falta
instalar svn en la máquina**. El código queda en `./src` (~1 GB) y `./src-3w`.

- Si el proceso se interrumpe, volver a ejecutar el script: detecta el checkout parcial y
  reanuda con `svn cleanup` + `svn update`.
- Si querés actualizar el código más adelante: ver [Operación](OPERACION.md#actualizar-el-código).

> El código de Guaraní pertenece a SIU y se descarga del repositorio Colab de la
> institución. **No se incluye en el repositorio Git** ni debe subirse a GitHub.

## 4. Levantar los contenedores

```bash
./scripts/02-up.sh
```

El script construye la imagen y levanta `db` y `gestion`. Para seguir la instalación:

```bash
docker compose logs -f gestion
```

En la primera ejecución verás, en orden:

1. `Esperando PostgreSQL ...` / `PostgreSQL disponible.`
2. `Instalando Toba 3.4.1 ...`
3. `Carga del Proyecto guarani ...`
4. `Instalando guarani 3.23.0 ...` (ddls, datos básicos, constraints, usuarios)
5. `Creando auditoria ...`
6. `fop configurado ...`, `Syntax OK`, `Iniciando JavaBridge Jasper ...`
7. `Apache iniciado. Gestión: http://localhost:8090/guarani/3.23`
8. En `autogestion`: `La instalación de Guaraní Autogestión se realizó con éxito` y
   `Apache de Autogestión iniciado. URL: http://localhost:8091/3w`
9. En `preinscripcion`: creación de la base, carga del esquema 3.23.0, creación del
   usuario admin y `Apache de Preinscripcion iniciado.`
10. En `kolla`: creación del rol/base, instalación Toba, carga de datos y
    `Apache de Kolla iniciado.`

Tiempo orientativo: 5–15 min para el checkout, 5–10 min para el build y 1–3 min para la
instalación de la base, según conexión y máquina.

> Es normal ver `La base ya existe, no se puede determinar el encoding` y
> `pg_dump: error: no matching schemas were found`: son avisos de una instalación nueva
> sobre una base vacía, no errores.

## 5. Primer acceso

Abrir http://localhost:8090/guarani/3.23

- Usuario: **toba**
- Clave: la definida en `TOBA_PASSWORD` (por defecto `toba`)

Cambiar la clave del usuario `toba` después del primer ingreso.

Para Autogestión entrá en http://localhost:8091/3w con una **persona/alumno** dada de alta
en Guaraní. El usuario `toba` es solo para Gestión. Ver [3W.md](3W.md).

Para Preinscripción: alumnos en http://localhost:8092/preinscripcion/iupa y panel de
administración en http://localhost:8092/preinscripcion_admin/iupa (`admin` / la clave de
`.env`). Ver [PREINSCRIPCION.md](PREINSCRIPCION.md).

Kolla está en http://localhost:8093/kolla (`toba` / la clave de `KOLLA_PASSWORD`).
Ver [KOLLA.md](KOLLA.md).

## 6. Verificación

```bash
docker compose ps                                   # ambos servicios en estado healthy
curl -o /dev/null -w "%{http_code}\n" http://localhost:8090/guarani/3.23/   # 200
curl -o /dev/null -w "%{http_code}\n" http://localhost:8090/toba_editor/3.4/ # 200
curl -o /dev/null -w "%{http_code}\n" http://localhost:8090/guarani/3.23/rest/ # 302
curl -o /dev/null -w "%{http_code}\n" http://localhost:8091/3w/                  # 200
curl -Ls -o /dev/null -w "%{http_code}\n" http://localhost:8092/preinscripcion_admin/iupa/ # 200
curl -o /dev/null -w "%{http_code}\n" http://localhost:8093/kolla/                         # 200

docker compose exec -T db psql -U "$POSTGRES_USER" -d preinscripcion \
  -tAc "select version_base from app_versiones_base"   # 3.23.0

docker compose exec -T autogestion sh -c \
  'cd /opt/guarani-3w/bin && ./guarani test_conexion des01'   # SE CONECTO CON EXITO

docker compose exec db psql -U "$POSTGRES_USER" -d guarani3 \
  -tAc "select usuario from desarrollo.apex_usuario where usuario='toba'"

docker compose exec gestion sh -c 'pgrep -af php.java.bridge.Standalone'
```

Si `docker compose ps` muestra `healthy` en ambos servicios, la instalación quedó correcta.

## 7. Notas por sistema operativo

### macOS

- Funciona en Intel y Apple Silicon (imágenes arm64 nativas).
- Docker Desktop debe tener acceso a la carpeta del proyecto (en `Settings → Resources → File sharing`).
- Si 8090 está ocupado por otro contenedor, cambiar `GESTION_PORT`.

### Linux

- El usuario debe pertenecer al grupo `docker` para ejecutar `docker compose` sin `sudo`.
- En caso de SELinux/AppArmor restrictivo, puede ser necesario ajustar el montaje de volúmenes.

### Windows (WSL2)

- Clonar el repo **dentro de WSL2** (por ejemplo `~/guarani`), no en `C:\`, para evitar
  problemas de permisos y rendimiento con los volúmenes.
- Ejecutar todos los comandos desde una terminal WSL (Ubuntu/Debian).
- Los scripts son Bash: no funcionan desde `cmd` ni PowerShell clásico.

## 8. Subir el proyecto a GitHub

```bash
git init
git add .env.example docker-compose.yml Dockerfile .dockerignore .gitignore \
        docker scripts docs README.md
git status   # verificar que .env y src/ NO aparezcan
git commit -m "Docker para SIU-Guaraní Gestión 3.23.0"
git remote add origin https://github.com/<tu-usuario>/<repo>.git
git push -u origin main
```

Quien clone debe copiar `.env.example` a `.env`, completar sus propias credenciales de
Colab y ejecutar los dos scripts. Nunca commitear `.env`, `src/` ni logs.
