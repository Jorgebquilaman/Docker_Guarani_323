# SIU-Kolla 4.10.3

Módulo de encuestas integrado desde el archivo **`instalador_kolla_4.10.3.rar`**
descargado del Portal de Servicios de Comunidad del SIU, siguiendo la
[guía oficial de instalación desde cero](https://documentacion.siu.edu.ar/wiki/SIU-Kolla/Version_4.10.0/instalacion_desde_cero).

## Cómo se integró

| Paso de la documentación | Cómo quedó en el compose |
|---|---|
| Extraer el RAR | `scripts/05-extraer-kolla.sh` → `./src-kolla` (usa `bsdtar`) |
| Apache + PHP 8.1 con `gd`, `pdo_pgsql`, `curl`, `xsl`, `zip` | `Dockerfile.kolla` (además `intl`, `apcu`, `svn`, `nodejs`/`yarn`) |
| `composer install --no-dev` | en el build, más los scripts de assets del framework y de `manejador-salida-bootstrap` |
| `cp instalador.env.dist instalador.env` y completarlo | entrypoint genera `instalador.env` desde variables de `.env` |
| `chmod +x bin/instalador` | en el build |
| `./bin/instalador proyecto:instalar` | entrypoint, con `--no-interaction --sin-mantenimiento --no-validar-servicios` |
| Permisos (`permisos:simple`) y `toba.conf` | entrypoint (`www-data`, symlink a `sites-enabled/kolla.conf`) |
| Quitar modo mantenimiento | `--sin-mantenimiento` en el instalador |
| `RewriteRule ^responder...` para habilitaciones públicas | entrypoint lo agrega a `toba.conf` si no está |

## Base de datos

Kolla tiene su **propia base** `kolla` (LATIN1, locale `C`) en el mismo PostgreSQL.
El instalador crea los esquemas `desarrollo` (metadata Toba), `referencia`, `kolla`
(negocio) y `desarrollo_logs`.

Se usa un **usuario de BD dedicado** `kolla` con clave simple (`KOLLA_DB_USER` /
`KOLLA_DB_PASSWORD`), porque Toba arma comandos de shell con la clave y los caracteres
`&`, `#` o `\` rompen esos comandos. El usuario `sarnal` sigue usándose para los demás
módulos y para tareas administrativas.

### Encoding de los SQL

Los archivos SQL del RAR están mezclados: `db/estructura.sql` es **UTF-8** y
`sql/datos/base/*.sql` es **LATIN1**. Como la base es LATIN1, el build convierte los SQL
UTF-8 a LATIN1 con `iconv`. Sin eso, los acentos ocupan el doble y fallan inserciones en
columnas `varchar(30)` (`Correo Electrónico alternativo`, etc.).

## Variables en `.env`

| Variable | Default | Uso |
|---|---|---|
| `KOLLA_PORT` | `8093` | Puerto HTTP |
| `KOLLA_ALIAS` | `/kolla` | Alias del proyecto |
| `KOLLA_PASSWORD` | `toba123*-a` | Clave del usuario administrador `toba` (mínimo 8 caracteres) |
| `KOLLA_DB_USER` | `kolla` | Usuario de BD dedicado |
| `KOLLA_DB_PASSWORD` | `kolla123` | Clave del usuario de BD |

## Acceso

- Kolla: http://localhost:8093/kolla
- Usuario inicial: **toba** / la clave de `KOLLA_PASSWORD`
- Editor Toba (si se instaló): `/toba_editor` dentro del mismo alias

## Verificación

```bash
docker compose ps                     # los 5 servicios healthy
curl -o /dev/null -w "%{http_code}\n" http://localhost:8093/kolla/   # 200

docker compose exec -T db psql -U kolla -d kolla \
  -c "select table_schema, count(*) from information_schema.tables where table_schema in ('desarrollo','kolla','referencia') group by 1"

docker compose exec -T db psql -U kolla -d kolla \
  -c "select usuario, nombre from desarrollo.apex_usuario where usuario='toba'"

# Assets (deben dar 200)
curl -o /dev/null -w "%{http_code}\n" http://localhost:8093/kolla/toba/js/packages/jquery/dist/jquery.min.js
curl -o /dev/null -w "%{http_code}\n" http://localhost:8093/kolla/toba/siu/manejador_salida_bootstrap/css/global.css
```

Datos iniciales esperados: ~113 tablas en `kolla`, ~123 en `desarrollo`, 7 en `referencia`,
preguntas y unidad de gestión predeterminada cargadas.

## Persistencia

`instalacion/` está en el volumen `guarani_kolla_instalacion` y la base en
`guarani_pgdata`. Los reinicios y la reconstrucción de la imagen no reinstalan: el
entrypoint detecta el marcador `.docker-instalado`.

> Si se borran los volúmenes con `scripts/reset.sh`, el entrypoint vuelve a crear el rol,
> la base y la instalación desde cero. No hace falta volver a extraer el RAR si `src-kolla/`
> sigue presente (pero sí está ignorado por Git: un clone nuevo necesita el RAR).

## Producción

- Configurar el servidor SMTP en `instalacion/smtp.ini` antes de habilitar encuestas.
- Revisar `KOLLA_PROTOCOLO_URL_POST` (`http` en local, `https` si hay reverse proxy).
- Activar `'produccion' => true` en `instalacion/instalacion.ini` y compilar recursos
  según la documentación oficial (`bin/phinx`, `yarn`, etc.).
