# Seguridad y consideraciones para producción

Este armado está pensado para **desarrollo / demostración local**. Antes de usarlo en un
entorno accesible desde otros equipos, revisar los puntos siguientes.

## Credenciales

Todos los valores sensibles viven en `.env` (ignorado por Git) y se inyectan como variables
de entorno en los contenedores.

| Dato | Variable(s) | Recomendación |
|---|---|---|
| Usuario/clave SVN de Colab | `SVN_USER`, `SVN_PASSWORD` | No commitear. Rotar si se comparte por accidente. Cada usuario usa las suyas. |
| Usuario/clave PostgreSQL (admin) | `POSTGRES_USER`, `POSTGRES_PASSWORD` | Usar clave fuerte distinta de la del SVN. Sirve para tareas administrativas. |
| Clave de `toba` en Gestión | `TOBA_PASSWORD` | Cambiar en el primer acceso y actualizar `.env` antes de reinstalar. |
| Semilla de Gestión | `TOBA_SALT` | Cadena aleatoria larga. Afecta los hashes internos. |
| Usuario de 3w | persona de Guaraní | No existe usuario por defecto: dar de alta una persona con usuario/clave. |
| Admin de Preinscripción | `PREINSCRIPCION_ADMIN_USER`, `PREINSCRIPCION_ADMIN_PASSWORD` | Cambiar la clave por defecto `admin123`. |
| Clave de `toba` en Kolla | `KOLLA_PASSWORD` | Mínimo 8 caracteres. Rotar antes de producción. |
| Usuario/clave BD de Kolla | `KOLLA_DB_USER`, `KOLLA_DB_PASSWORD` | Dedicado; clave simple a propósito (Toba arma comandos shell con ella). |
| Clave de `toba` en Tehuelche | `TEHUELCHE_PASSWORD` | Mínimo 8 caracteres. Rotar antes de producción. |
| Usuario/clave BD de Tehuelche | `TEHUELCHE_DB_USER`, `TEHUELCHE_DB_PASSWORD` | Dedicado; misma razón que Kolla. |

Verificar siempre antes de un `git add`:

```bash
git status
git check-ignore -v .env src src-3w src-preinscripcion src-kolla src-tehuelche
```

Si una clave quedó expuesta en el historial de Git, rotarla en Colab/PostgreSQL y
reescribir el historial (`git filter-repo` o BFG).

## Red

| Puerto | Servicio | Acceso |
|---|---|---|
| 8090 | Gestión, editor, API REST | HTTP |
| 8091 | Autogestión 3w | HTTP |
| 8092 | Preinscripción (alumno y admin) | HTTP |
| 8093 | Kolla | HTTP |
| 8094 | Tehuelche | HTTP |
| 5434 | PostgreSQL | Solo administración |
| 8081 | JavaBridge (interno) | No publicado; solo `gestion` |

En producción:

- Limitar el acceso a los puertos HTTP con un firewall o reverse proxy.
- **Quitar el mapeo de `db.ports`** o restringir `5434` a `127.0.0.1`.
- Poner HTTPS delante de todos los módulos y activar `TOBA_FORZAR_HTTPS=on` donde
  corresponda (Gestión, Kolla, Tehuelche).
- En Kolla revisar `KOLLA_PROTOCOLO_URL_POST=https` cuando haya HTTPS.

## Usuarios y perfiles

- Cada módulo arranca con un usuario administrador propio: `toba` en Gestión/Kolla/Tehuelche,
  `admin` en Preinscripción y una persona dada de alta en 3w.
- Cambiar todas las claves por defecto y crear usuarios nominados con el mínimo permiso.
- Si se usa autenticación centralizada (SAML/OIDC), documentar los parámetros `SSO_SP_*`
  del instalador de SIU.

## Datos

Hay **cuatro bases** en el mismo PostgreSQL: `guarani3`, `preinscripcion`, `kolla` y
`tehuelche`. Todas en `LATIN1`.

Los volúmenes que deben entrar en el plan de backups son:

- `guarani_pgdata` (las cuatro bases)
- `guarani_instalacion`, `guarani_www`, `guarani_temp`, `guarani_metadatos`,
  `guarani_fw_www`, `guarani_fw_temp`
- `guarani_3w_instalacion`, `guarani_preinscripcion_instalacion`,
  `guarani_kolla_instalacion`, `guarani_tehuelche_instalacion`

Ver [Operación → Backup y restore](OPERACION.md#backup-y-restore).

- `docker compose down -v` (y `scripts/reset.sh`) **borra todas las bases**. El script pide
  confirmación por ese motivo.
- No cambiar el encoding de las bases después de cargar datos sin una migración planificada.

## Código fuente

- `src/`, `src-3w/` y `src-preinscripcion/` son checkouts SVN de SIU.
- `src-kolla/` y `src-tehuelche/` salen de los RAR del Portal de Servicios de Comunidad.
- **No subir ninguno a GitHub ni redistribuirlos**: el acceso está sujeto al convenio con la
  institución. Los RAR tampoco se versionan (`*.rar` en `.gitignore`).
- `.env.example` debe contener solo placeholders.

## Imágenes y dependencias

- Las imágenes base son públicas (`php`, `postgres`, `composer`, `alpine`). Las dependencias
  PHP se bajan de `satis.siu.edu.ar`, GitHub y npm según los lockfiles.
- Si el entorno es cerrado, replicar esas dependencias en un registry interno y fijar
  digests de imágenes en `docker-compose.yml`.
- Actualizar el sistema base de las imágenes (`apt-get upgrade`) de vez en cuando.

## Producción: checklist mínimo

- [ ] Claves rotadas y fuera del repositorio (las cinco credenciales de admin)
- [ ] `TOBA_SALT` aleatorio en cada módulo Toba
- [ ] Usuarios `toba`/`admin` con claves fuertes o deshabilitados
- [ ] HTTPS / reverse proxy delante de los cinco módulos
- [ ] Puertos HTTP filtrados y `5434` no expuesto públicamente
- [ ] `JavaBridge` (8081) sigue sin publicarse
- [ ] Backups automáticos de las cuatro bases y de todos los volúmenes de configuración
- [ ] Monitorización de `docker compose logs` y de los seis healthcheck
- [ ] Cron de notificaciones y SMTP real configurado
- [ ] Integración Tehuelche ↔ Guaraní configurada desde la interfaz
