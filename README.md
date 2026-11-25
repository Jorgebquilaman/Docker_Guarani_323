# SIU-Guaraní Gestión 3.23.0 en Docker

Entorno local de **SIU-Guaraní Gestión 3.23.0** (nodo IUPA) sobre Docker, siguiendo la
[guía oficial de instalación en Linux](https://documentacion.siu.edu.ar/wiki/SIU-Guarani/version3.23.0/instalacion_desde_cero/instalacion/gestion/linux).

## Acceso rápido

```bash
cp .env.example .env       # 1) completar credenciales de Colab
./scripts/01-svn-checkout.sh
./scripts/02-up.sh
docker compose logs -f gestion
```

- **Gestión:** http://localhost:8090/guarani/3.23 — `toba` / `toba`
- **Editor:** http://localhost:8090/toba_editor/3.4
- **API REST:** http://localhost:8090/guarani/3.23/rest/
- **PostgreSQL:** `localhost:5434`, base `guarani3`

## Documentación

| Documento | Contenido |
|---|---|
| [Instalación](docs/INSTALACION.md) | Requisitos, credenciales, paso a paso en macOS / Linux / Windows, puertos, primera verificación |
| [Operación](docs/OPERACION.md) | Comandos diarios, logs, backups, actualización de código, reinstalación, envío de emails |
| [Arquitectura](docs/ARQUITECTURA.md) | Servicios, volúmenes, flujo de arranque, decisiones de configuración |
| [Resolución de problemas](docs/TROUBLESHOOTING.md) | Errores frecuentes con comandos de diagnóstico |
| [Seguridad y producción](docs/SEGURIDAD.md) | Manejo de credenciales, qué cambiar antes de producción |

## Contenido técnico

| Servicio | Imagen | Función |
|---|---|---|
| `db` | `postgres:14-bookworm` | Base `guarani3`, encoding LATIN1, `bytea_output=escape` |
| `gestion` | build local (`php:8.1-apache-bookworm`) | Apache + PHP 8.1 + Composer + Java + Jasper |

Código fuente: `https://colab.siu.edu.ar/svn/guarani3/nodos/iupa/gestion/trunk/3.23.0`.

## Subir a GitHub

Sí se puede. `.gitignore` excluye `.env` (credenciales) y `src/` (código del SVN de SIU).
Ver [Instalación → Subir el proyecto a GitHub](docs/INSTALACION.md#8-subir-el-proyecto-a-github).
