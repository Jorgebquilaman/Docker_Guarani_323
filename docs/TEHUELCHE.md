# SIU-Tehuelche 4.5.2

Módulo de gestión de becas integrado desde **`instalador_tehuelche_4.5.2.rar`**
(colocarlo en `instaladores/` o en la raíz del proyecto), del Portal de Servicios de
Comunidad del SIU, siguiendo la
[guía oficial de instalación de 4.5](https://documentacion.siu.edu.ar/wiki/SIU-Tehuelche/version_4.5/instalacion).

## Cómo se integró

| Paso de la documentación | Cómo quedó en el compose |
|---|---|
| Extraer el RAR | `scripts/06-extraer-tehuelche.sh` → `./src-tehuelche` (`bsdtar`) |
| Apache 2.4 + PHP 8.1 + PostgreSQL + Yarn + Composer + Git | `Dockerfile.tehuelche` (además `xsl`, `intl`, `apcu`, `svn`) |
| `composer install --no-dev` | en el build, con los `post-install-cmd` del framework y `manejador-salida-bootstrap` |
| `instalador.env.dist` → `instalador.env` | entrypoint lo genera desde variables de `.env` |
| `chmod +x bin/instalador` | en el build |
| `./bin/instalador proyecto:instalar` | entrypoint con `--no-interaction --sin-mantenimiento --no-validar-servicios` |
| `permisos:simple`, `toba.conf`, quitar mantenimiento | entrypoint y `--sin-mantenimiento` |
| Importar propuestas desde Guaraní | pendiente: paso 11 de la guía oficial (ver abajo) |

La instalación usa el mismo truco del script oficial `docker/bin/crear-bd.sh`: se instala
en un directorio `instalacion.tmp` (que no existe) y luego se copia al volumen, porque el
instalador rechaza un directorio de instalación ya existente.

## Base de datos

Tehuelche tiene su propia base `tehuelche` (LATIN1) en el mismo PostgreSQL, con usuario
dedicado `tehuelche`. Esquemas creados por el instalador:

| Esquema | Contenido |
|---|---|
| `desarrollo` | metadata Toba |
| `desarrollo_logs` | logs |
| `referencia` | referencia |
| `tehuelche` | negocio (becas, solicitudes, censos) |

El usuario de BD es propio porque Toba arma comandos shell con la clave y los caracteres
especiales de la clave original rompen esos comandos.

Algunos SQL del RAR vienen en UTF-8 (`sql/migraciones/4.1.0/nuevas_tablas.sql`) y la base
es LATIN1: el build los convierte con `iconv`, igual que en Kolla.

## Variables en `.env`

| Variable | Default | Uso |
|---|---|---|
| `TEHUELCHE_PORT` | `8094` | Puerto HTTP |
| `TEHUELCHE_ALIAS` | `/tehuelche` | Alias del proyecto |
| `TEHUELCHE_PASSWORD` | `toba123*-a` | Clave del usuario admin `toba` (mínimo 8 caracteres) |
| `TEHUELCHE_DB_USER` | `tehuelche` | Usuario de BD dedicado |
| `TEHUELCHE_DB_PASSWORD` | `tehuelche123` | Clave del usuario de BD |

## Acceso

- Tehuelche: http://localhost:8094/tehuelche
- Usuario inicial: **toba** / la clave de `TEHUELCHE_PASSWORD`

## Verificación

```bash
docker compose ps                        # los 6 servicios healthy
curl -o /dev/null -w "%{http_code}\n" http://localhost:8094/tehuelche/   # 200

docker compose exec -T db psql -U tehuelche -d tehuelche \
  -c "select table_schema, count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema') group by 1 order by 1"

docker compose exec -T db psql -U tehuelche -d tehuelche \
  -c "select usuario, nombre from desarrollo.apex_usuario where usuario='toba'"

# Assets del framework (deben dar 200)
curl -o /dev/null -w "%{http_code}\n" http://localhost:8094/tehuelche/toba/js/packages/jquery/dist/jquery.min.js
curl -o /dev/null -w "%{http_code}\n" http://localhost:8094/tehuelche/toba/siu/manejador_salida_bootstrap/css/global.css
```

Resultado esperado: ~87 tablas en `tehuelche`, ~122 en `desarrollo`, 12 en
`desarrollo_logs` y 7 en `referencia`; datos base y migraciones hasta 4.5.1 aplicadas.

## Integración con Guaraní (paso 11 de la guía)

La documentación indica que después de instalar hay que:

1. [Vincular Tehuelche con Guaraní](https://documentacion.siu.edu.ar/wiki/SIU-Tehuelche/version_4.5/integracion),
   configurando la conexión REST/hacia la base de Guaraní.
2. Entrar a **Administración → Sincronizar Propuestas** e importar las propuestas
   formativas desde Guaraní.

Ese paso requiere credenciales/configuración de la institución y se hace desde la interfaz;
no quedó automatizado. Como Guaraní corre en el mismo Docker, el host de la integración
puede apuntar a `http://gestion` (red `guarani_default`) o a
`http://localhost:8090/guarani/3.23` según el caso.

## Persistencia

`instalacion/` vive en el volumen `guarani_tehuelche_instalacion` y la base en
`guarani_pgdata`. Reiniciar o reconstruir la imagen no reinstala (marcador
`.docker-instalado`). `scripts/reset.sh` (`down -v`) sí borra todo y vuelve a instalar;
para un clone nuevo hay que volver a poner el RAR y ejecutar `scripts/06-extraer-tehuelche.sh`.
