<div align="center">

<img src="https://img.shields.io/badge/SIU--Guaran%C3%AD-3.23.0-2E7D32?style=for-the-badge" alt="Versión">
<img src="https://img.shields.io/badge/PHP-8.1-777BB4?style=for-the-badge&logo=php&logoColor=white" alt="PHP">
<img src="https://img.shields.io/badge/PostgreSQL-14-336791?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
<img src="https://img.shields.io/badge/Apache-2.4-D22128?style=for-the-badge&logo=apache&logoColor=white" alt="Apache">
<img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
<img src="https://img.shields.io/badge/arm64%20%7C%20amd64-4C1?style=for-the-badge" alt="Arquitecturas">

# 🐘 SIU-Guaraní Gestión + Autogestión + Preinscripción + Kolla en Docker

**Entorno local completo, reproducible y listo para usar en macOS, Linux o Windows (WSL2).**

[Sobre el proyecto](#-qué-incluye) · [Inicio rápido](#-inicio-rápido) · [Accesos](#-accesos) · [Documentación](#-documentación) · [Seguridad](#-seguridad)

</div>

---

## ✨ Qué incluye

| | |
|---|---|
| 🧱 **Cinco servicios** | PostgreSQL 14 + Gestión + Autogestión 3w + Preinscripción + Kolla (cada módulo con su Apache) |
| 📦 **Instalación automática** | Toba, carga del proyecto, esquema de negocio y auditoría en el primer arranque |
| 🔁 **Idempotente** | Los reinicios y las reconstrucciones no reinstalan ni pierden datos |
| 🌐 **Todo publicado** | Gestión, editor, API REST y JavaBridge de reportes |
| 📖 **Documentación completa** | Instalación, operación, arquitectura, troubleshooting y seguridad |

Basado en la [guía oficial de instalación en Linux del SIU](https://documentacion.siu.edu.ar/wiki/SIU-Guarani/version3.23.0/instalacion_desde_cero/instalacion/gestion/linux).
Código fuente: `nodos/iupa/gestion/trunk/3.23.0` del repositorio Colab.

---

## 🚀 Inicio rápido

> **Requisitos previos:** Docker con Compose v2, ~10 GB libres y credenciales de Colab con acceso al nodo `iupa`.

```bash
# 1. Clonar y entrar
git clone https://github.com/Jorgebquilaman/Docker_Guarani_323.git
cd Docker_Guarani_323

# 2. Configurar credenciales
cp .env.example .env
#    editar .env con tu usuario/clave de Colab y la clave de PostgreSQL

# 3. Descargar el código fuente (no hace falta svn instalado)
./scripts/01-svn-checkout.sh
./scripts/03-svn-checkout-3w.sh   # Autogestión (3w)
./scripts/04-svn-checkout-preinscripcion.sh  # Preinscripción
./scripts/05-extraer-kolla.sh                # Kolla (desde el .rar descargado)

# 4. Construir y levantar
./scripts/02-up.sh

# 5. Seguir la instalación
docker compose logs -f gestion
```

Cuando aparezca `Apache iniciado. Gestión: http://localhost:8090/guarani/3.23`, ya está listo. ⏱️ Primera vez: 10–25 min según la conexión.

<details>
<summary>👀 ¿Qué hace el paso 4 por dentro?</summary>

1. Espera a que PostgreSQL esté disponible.
2. Ejecuta `toba instalacion instalar` → `guarani cargar -d` → `guarani instalar` → `crear_auditoria`.
3. Configura `menu=2`, la ruta de `fop`, los permisos y el alias de Apache.
4. Arranca el JavaBridge de Jasper en el puerto interno `8081`.
5. Marca la instalación como completada para no repetirla.

</details>

---

## 🔑 Accesos

| Servicio | URL | Credenciales |
|---|---|---|
| 🖥️ **Gestión** | http://localhost:8090/guarani/3.23 | `toba` / `toba` |
| 🎓 **Autogestión (3w)** | http://localhost:8091/3w | Usuario de alumno/persona de Guaraní |
| 📝 **Preinscripción (alumno)** | http://localhost:8092/preinscripcion/iupa | Se crea desde el alta de preinscripción |
| 🛡️ **Preinscripción (admin)** | http://localhost:8092/preinscripcion_admin/iupa | `admin` / `admin123` (configurable en `.env`) |
| 📊 **Kolla** | http://localhost:8093/kolla | `toba` / `toba123*-a` (configurable en `.env`) |
| 🛠️ **Editor Toba** | http://localhost:8090/toba_editor/3.4 | `toba` / `toba` |
| 🔌 **API REST** | http://localhost:8090/guarani/3.23/rest/ | Requiere configuración OAuth |
| 🗄️ **PostgreSQL** | `localhost:5434` · base `guarani3` | Las de `.env` |

> ¿Puerto ocupado? Cambiá `GESTION_PORT`, `W3_PORT`, `PREINSCRIPCION_PORT`, `KOLLA_PORT` y `DB_PORT_HOST` en `.env`. No hace falta tocar el `docker-compose.yml`.
> Para entrar a 3w necesitás una persona con usuario en Guaraní; en Preinscripción el administrador se crea automáticamente.

---

## ✅ Verificación rápida

```bash
docker compose ps                                                          # healthy / healthy
curl -o /dev/null -w "%{http_code}\n" http://localhost:8090/guarani/3.23/   # 200
curl -o /dev/null -w "%{http_code}\n" http://localhost:8090/toba_editor/3.4/ # 200
curl -o /dev/null -w "%{http_code}\n" http://localhost:8090/guarani/3.23/rest/ # 302
curl -o /dev/null -w "%{http_code}\n" http://localhost:8091/3w/                  # 200
curl -Ls -o /dev/null -w "%{http_code}\n" http://localhost:8092/preinscripcion_admin/iupa/  # 200
curl -o /dev/null -w "%{http_code}\n" http://localhost:8093/kolla/                         # 200
```

- [x] Checkout SVN de la revisión publicada
- [x] Esquemas `desarrollo`, `negocio` y `negocio_auditoria`
- [x] Usuario `toba` creado
- [x] Reportes Jasper con OpenJDK 17

---

## 📚 Documentación

| Guía | Qué encontrás |
|---|---|
| 📥 [Instalación](docs/INSTALACION.md) | Requisitos, credenciales, `.env`, puertos, macOS/Linux/WSL2 y publicación en GitHub |
| 🎓 [Autogestión 3w](docs/3W.md) | Instalación, configuración, unidad académica, reportes y verificación |
| 📝 [Preinscripción](docs/PREINSCRIPCION.md) | Base propia, puntos de acceso, usuario admin y configuración desde Gestión |
| 📊 [Kolla](docs/KOLLA.md) | Instalador del RAR, base propia, encoding, usuario admin y habilitaciones públicas |
| ⚙️ [Operación](docs/OPERACION.md) | Comandos diarios, logs, backups, updates, reset, cron y API REST |
| 🏗️ [Arquitectura](docs/ARQUITECTURA.md) | Servicios, imagen, flujo del entrypoint, alias y decisiones |
| 🩺 [Troubleshooting](docs/TROUBLESHOOTING.md) | Errores frecuentes con comandos de diagnóstico |
| 🔐 [Seguridad](docs/SEGURIDAD.md) | Credenciales, red, backups y checklist de producción |

---

## 🧱 Estructura

```
.
├── docker-compose.yml      # db + gestion + autogestion + preinscripcion
├── Dockerfile              # Gestión: PHP 8.1 + Apache + Java
├── Dockerfile.3w           # Autogestión: PHP 8.1 + Apache + intl
├── Dockerfile.preinscripcion
├── Dockerfile.kolla        # Kolla: PHP 8.1 + xsl + yarn
├── docker/entrypoint*.sh   # instalación automática y arranque
├── docker/db-init/         # crea la base "preinscripcion" en el init de PostgreSQL
├── scripts/                # checkout SVN, extracción del RAR, up y reset
├── docs/                   # documentación completa
├── .env.example            # plantilla sin secretos
└── src/                    # checkout SVN (ignorado por Git)
```

---

## 🔐 Seguridad

- `.env` contiene tus credenciales y **está ignorado por Git**: nunca lo subas.
- `src/` es código de SIU descargado de Colab: **tampoco se versiona**.
- En producción: rotar la clave de `toba`, cambiar `TOBA_SALT`, activar HTTPS y no exponer el puerto `5434`.

Ver [SEGURIDAD.md](docs/SEGURIDAD.md) para el detalle.

---

<div align="center">

Hecho para el nodo **IUPA** · SIU-Guaraní 3.23.0 · [Repositorio](https://github.com/Jorgebquilaman/Docker_Guarani_323)

</div>
