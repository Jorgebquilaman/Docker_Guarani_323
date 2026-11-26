<div align="center">

<img src="https://img.shields.io/badge/SIU--Guaran%C3%AD-3.23.0-2E7D32?style=for-the-badge" alt="Versión">
<img src="https://img.shields.io/badge/PHP-8.1-777BB4?style=for-the-badge&logo=php&logoColor=white" alt="PHP">
<img src="https://img.shields.io/badge/PostgreSQL-14-336791?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
<img src="https://img.shields.io/badge/Apache-2.4-D22128?style=for-the-badge&logo=apache&logoColor=white" alt="Apache">
<img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
<img src="https://img.shields.io/badge/arm64%20%7C%20amd64-4C1?style=for-the-badge" alt="Arquitecturas">

# 🐘 SIU-Guaraní Gestión + Autogestión + Preinscripción + Kolla + Tehuelche en Docker

**Entorno local completo, reproducible y listo para usar en macOS, Linux o Windows (WSL2).**

[Sobre el proyecto](#-qué-incluye) · [Inicio rápido](#-inicio-rápido) · [Accesos](#-accesos) · [Documentación](#-documentación) · [Seguridad](#-seguridad)

</div>

---

## ✨ Qué incluye

| | |
|---|---|
| 🧱 **Seis servicios** | PostgreSQL 14 + Gestión + Autogestión 3w + Preinscripción + Kolla + Tehuelche (cada módulo con su Apache) |
| 📦 **Instalación automática** | Toba, proyectos, esquemas, datos base y migraciones de los cinco módulos en el primer arranque |
| 🔁 **Idempotente** | Los reinicios y las reconstrucciones no reinstalan ni pierden datos |
| 🌐 **Todo publicado** | Gestión, editor, API REST, Autogestión, Preinscripción, Kolla y Tehuelche |
| 📖 **Documentación completa** | Instalación, operación, arquitectura, troubleshooting y seguridad |

Basado en la [guía oficial de instalación en Linux del SIU](https://documentacion.siu.edu.ar/wiki/SIU-Guarani/version3.23.0/instalacion_desde_cero/instalacion/gestion/linux).
Código fuente: `nodos/iupa/gestion/trunk/3.23.0` del repositorio Colab.

---

## 🚀 Inicio rápido

> **Requisitos previos:** Docker con Compose v2, ~15 GB libres, credenciales de Colab con acceso al nodo `iupa` y los instaladores `instalador_kolla_4.10.3.rar` e `instalador_tehuelche_4.5.2.rar` dentro de `instaladores/` (o en la raíz; se descargan del Portal de Servicios de Comunidad del SIU).

```bash
# 1. Clonar y entrar
git clone https://github.com/Jorgebquilaman/Docker_Guarani_323.git
cd Docker_Guarani_323

# 2. Configurar credenciales
cp .env.example .env
#    editar .env: credenciales de Colab, claves de BD y de los usuarios admin

# 3. Descargar el código fuente (no hace falta svn instalado)
./scripts/01-svn-checkout.sh
./scripts/03-svn-checkout-3w.sh   # Autogestión (3w)
./scripts/04-svn-checkout-preinscripcion.sh  # Preinscripción
./scripts/05-extraer-kolla.sh                # Kolla (lee instaladores/*.rar o la raíz)
./scripts/06-extraer-tehuelche.sh            # Tehuelche (ídem)

# 4. Construir y levantar
./scripts/02-up.sh

# 5. Seguir la instalación
docker compose logs -f gestion
```

Cuando los seis contenedores estén `healthy` y aparezca `Apache iniciado` en cada log, ya está listo. ⏱️ Primera vez: 20–40 min según la conexión (checkouts, RARs, Composer, Yarn y bases).

<details>
<summary>👀 ¿Qué hace el paso 4 por dentro?</summary>

1. Espera a que PostgreSQL esté disponible y crea las bases propias que falten.
2. Gestión: `toba instalacion instalar` → `guarani cargar -d` → `guarani instalar` → `crear_auditoria`.
3. 3w y Preinscripción: generan `config.php`/`alias.conf` desde plantillas y crean sus usuarios.
4. Kolla y Tehuelche: instalan en `instalacion.tmp`, convierten los SQL a LATIN1 y copian el resultado al volumen.
5. Configura `menu=2`, `fop`, permisos `www-data` y los alias de Apache.
6. Arranca el JavaBridge de Jasper en `8081` y marca cada instalación para no repetirla.

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
| 🎓 **Tehuelche** | http://localhost:8094/tehuelche | `toba` / `toba123*-a` (configurable en `.env`) |
| 🛠️ **Editor Toba** | http://localhost:8090/toba_editor/3.4 | `toba` / `toba` |
| 🔌 **API REST** | http://localhost:8090/guarani/3.23/rest/ | Requiere configuración OAuth |
| 🗄️ **PostgreSQL** | `localhost:5434` · bases `guarani3`, `preinscripcion`, `kolla`, `tehuelche` | `POSTGRES_*` (admin) y usuarios propios de Kolla/Tehuelche |

> ¿Puerto ocupado? Cambiá `GESTION_PORT`, `W3_PORT`, `PREINSCRIPCION_PORT`, `KOLLA_PORT`, `TEHUELCHE_PORT` y `DB_PORT_HOST` en `.env`. No hace falta tocar el `docker-compose.yml`.
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
curl -o /dev/null -w "%{http_code}\n" http://localhost:8094/tehuelche/                     # 200
```

- [x] Checkouts SVN (Gestión 3.23.0, 3w 3.23.0, Preinscripción 3.23.0)
- [x] RARs extraídos (Kolla 4.10.3 y Tehuelche 4.5.2)
- [x] Cuatro bases LATIN1 con sus esquemas y datos base
- [x] Usuarios admin creados en cada módulo
- [x] Reportes Jasper con OpenJDK 17

---

## 📚 Documentación

| Guía | Qué encontrás |
|---|---|
| 📥 [Instalación](docs/INSTALACION.md) | Requisitos, credenciales, `.env`, puertos, macOS/Linux/WSL2 y publicación en GitHub |
| 🎓 [Autogestión 3w](docs/3W.md) | Instalación, configuración, unidad académica, reportes y verificación |
| 📝 [Preinscripción](docs/PREINSCRIPCION.md) | Base propia, puntos de acceso, usuario admin y configuración desde Gestión |
| 📊 [Kolla](docs/KOLLA.md) | Instalador del RAR, base propia, encoding, usuario admin y habilitaciones públicas |
| 🎓 [Tehuelche](docs/TEHUELCHE.md) | Instalador del RAR, base propia, esquemas, usuario admin e integración con Guaraní |
| ⚙️ [Operación](docs/OPERACION.md) | Comandos diarios, logs, backups, updates, reset, cron y API REST |
| 🏗️ [Arquitectura](docs/ARQUITECTURA.md) | Servicios, imagen, flujo del entrypoint, alias y decisiones |
| 🩺 [Troubleshooting](docs/TROUBLESHOOTING.md) | Errores frecuentes con comandos de diagnóstico |
| 🔐 [Seguridad](docs/SEGURIDAD.md) | Credenciales, red, backups y checklist de producción |

---

## 🧱 Estructura

```
.
├── docker-compose.yml      # db + gestion + 3w + preinscripcion + kolla + tehuelche
├── Dockerfile              # Gestión: PHP 8.1 + Apache + Java
├── Dockerfile.3w           # Autogestión: PHP 8.1 + Apache + intl
├── Dockerfile.preinscripcion
├── Dockerfile.kolla        # Kolla: PHP 8.1 + xsl + yarn
├── Dockerfile.tehuelche    # Tehuelche: PHP 8.1 + xsl + yarn
├── docker/entrypoint*.sh   # instalación automática y arranque
├── docker/db-init/         # crea la base "preinscripcion" en el init de PostgreSQL
├── scripts/                # checkout SVN, extracción de RARs, up y reset
├── instaladores/           # colocar los RAR aquí (o en la raíz); ignorado por Git
├── docs/                   # documentación completa
├── .env.example            # plantilla sin secretos
└── src*/                   # src, src-3w, src-preinscripcion, src-kolla, src-tehuelche
                            # (todos ignorados por Git)
```

---

## 🔐 Seguridad

- `.env` contiene tus credenciales y **está ignorado por Git**: nunca lo subas.
- `src*/` contiene código de SIU (SVN y RAR): **tampoco se versiona**.
- En producción: rotar las claves de los usuarios admin de los cinco módulos, cambiar los salts, activar HTTPS y no exponer el puerto `5434`.

Ver [SEGURIDAD.md](docs/SEGURIDAD.md) para el detalle.

---

<div align="center">

Hecho para el nodo **IUPA** · Guaraní 3.23.0 · 3w · Preinscripción · Kolla 4.10.3 · Tehuelche 4.5.2 · [Repositorio](https://github.com/Jorgebquilaman/Docker_Guarani_323)

</div>
