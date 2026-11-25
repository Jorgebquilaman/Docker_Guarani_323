# Seguridad y consideraciones para producción

Este armado está pensado para **desarrollo / demostración local**. Antes de usarlo en un
entorno accesible desde otros equipos, revisar los puntos siguientes.

## Credenciales

| Dato | Dónde vive | Recomendación |
|---|---|---|
| Usuario/clave SVN de Colab | `.env` (variables `SVN_USER`, `SVN_PASSWORD`) | No commitear. Rotar si se comparte por accidente. Cada usuario usa las suyas. |
| Usuario/clave PostgreSQL | `.env` (`POSTGRES_USER`, `POSTGRES_PASSWORD`) | No commitear. Usar una clave fuerte distinta de la del SVN. |
| Clave de `toba` | `.env` (`TOBA_PASSWORD`) | Cambiarla en el primer acceso y actualizar `.env` antes de reinstalar. |
| `TOBA_SALT` | `.env` | Reemplazar por una cadena aleatoria larga. Afecta los hashes internos. |

`.env` está en `.gitignore` y `.dockerignore`. Verificar siempre antes de un `git add`:

```bash
git status
git check-ignore -v .env src
```

Si una clave quedó expuesta en el historial de Git, rotarla en Colab/PostgreSQL y
reescribir el historial (`git filter-repo` o BFG).

## Red

- El compose publica **8090** (HTTP) y **5434** (PostgreSQL). En producción, limitar el
  acceso al puerto de la base con un firewall o quitar el mapeo de `db.ports`.
- JavaBridge escucha en **8081** pero no se publica: solo es accesible desde `gestion`.
- Guaraní no viene con HTTPS. Para producción, poner un reverse proxy (nginx/Traefik)
  delante y configurar `TOBA_FORZAR_HTTPS=on` en `instalador.env` / `instalacion.ini`.

## Usuarios y perfiles

- El usuario inicial `toba` es superadministrador. Crear usuarios nominados y quitar los
  permisos amplios del usuario `toba`.
- Después del primer login, cambiar la clave desde **Administrar personas**.
- Si se usa autenticación centralizada (SAML/OIDC), documentar los parámetros
  `SSO_SP_*` del instalador de SIU.

## Datos

- Los volúmenes `guarani_pgdata` y `guarani_instalacion` contienen toda la información.
  Deben incluirse en el plan de backups: ver [Operación → Backup y restore](OPERACION.md#backup-y-restore).
- Hacer `docker compose down -v` **borra la base de datos**. El script `reset.sh` pide
  confirmación por ese motivo.
- La base se crea en `LATIN1`; no cambiar el encoding después de cargar datos sin una
  migración planificada.

## Código fuente

- `src/` es un checkout del SVN de SIU. **No subirlo a GitHub ni redistribuirlo**: el
  acceso está sujeto al convenio con la institución y al repositorio Colab correspondiente.
- Si el repo Git es público, `.env.example` debe contener solo placeholders.

## Imágenes y dependencias

- Las imágenes base son públicas (`php`, `postgres`, `composer`, `alpine`). Las dependencias
  PHP se bajan de `satis.siu.edu.ar` y GitHub según `composer.lock`.
- Para un entorno cerrado, replicar esas dependencias en un registry interno y fijar
  digests de imágenes en `docker-compose.yml`.
- Actualizar el sistema base (`apt-get upgrade`) de vez en cuando reconstruyendo la imagen.

## Producción: checklist mínimo

- [ ] Claves rotadas y fuera del repositorio
- [ ] `TOBA_SALT` aleatorio
- [ ] Usuario `toba` con clave fuerte o deshabilitado
- [ ] HTTPS / reverse proxy y `TOBA_FORZAR_HTTPS=on`
- [ ] Puerto 5434 no expuesto públicamente
- [ ] Backups automáticos de `guarani_pgdata` e `instalacion`
- [ ] Monitorización de `docker compose logs` y del healthcheck
- [ ] Cron de notificaciones configurado con SMTP real
