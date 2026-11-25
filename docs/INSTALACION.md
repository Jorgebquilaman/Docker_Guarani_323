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
DB_PORT_HOST=5434

TOBA_PASSWORD=toba
TOBA_SALT='semilla_aleatoria_larga'
```

**Reglas para los valores:**

- Usar **comillas simples** en las claves: la clave de ejemplo contiene `!`, `&`, `%` y `^`.
- `SVN_*`: credenciales reales de Colab (las mismas que se usan para el SVN).
- `POSTGRES_*`: usuario/clave de la base local del compose. Pueden ser los mismos valores.
- `GESTION_PORT`: puerto HTTP en el host. Cambiar si 8090 está ocupado.
- `DB_PORT_HOST`: puerto para conectarse a Postgres desde el host. Cambiar si 5434 está ocupado.
- `TOBA_PASSWORD`: clave del usuario administrador `toba` de Guaraní.
- `TOBA_SALT`: semilla interna; cambiar por una cadena aleatoria larga.

### Puertos

Verificar antes de empezar:

```bash
# macOS / Linux
lsof -nP -iTCP -sTCP:LISTEN | grep -E ':(8090|5434)\b'

# Windows (WSL2)
netstat -ano | findstr ":8090 :5434"
```

Si hay conflicto, editar `GESTION_PORT` y `DB_PORT_HOST` en `.env`. **No hace falta**
tocar `docker-compose.yml`.

## 3. Descargar el código fuente

```bash
./scripts/01-svn-checkout.sh
```

El script usa un contenedor `alpine` con `subversion`, por lo que **no hace falta instalar
svn en la máquina**. El código queda en `./src` (~1 GB).

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

## 6. Verificación

```bash
docker compose ps                                   # ambos servicios en estado healthy
curl -o /dev/null -w "%{http_code}\n" http://localhost:8090/guarani/3.23/   # 200
curl -o /dev/null -w "%{http_code}\n" http://localhost:8090/toba_editor/3.4/ # 200
curl -o /dev/null -w "%{http_code}\n" http://localhost:8090/guarani/3.23/rest/ # 302

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
