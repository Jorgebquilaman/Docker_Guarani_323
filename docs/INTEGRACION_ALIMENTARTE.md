# Integración Alimentarte ↔ Guaraní 3w

Alimentarte (https://github.com/<tu-usuario>/Alimentarte, en `/Users/jorge/Tmp/Alimentarte`)
acepta dos vías nuevas para alumnos:

1. **Login directo**: DNI + clave de Guaraní (usuario de Autogestión 3w).
2. **SSO desde 3w**: botón “Comedor Universitario (Alimentarte)” que entra sin pedir la clave otra vez.

Los perfiles **Admin** y **PersonalComedor** siguen usando su login local con email/clave.

## Arquitectura

```
Login directo:  DNI + clave ──► Alimentarte.API ──(Npgsql read-only)──► guarani3
                                   │  BCrypt.Verify(md5(clave), mdp_personas.clave)
                                   ▼  Alumno por DNI ──► JWT de Alimentarte

SSO desde 3w:   alumno logueado ──► operación "alimentarte" (personalización iupa)
                                   │  JWT HS256 firmado (firebase/php-jwt), exp 120 s
                                   ▼  http://localhost:5173/sso#token=...
                                   │  POST /api/auth/sso
                                   ▼  Alumno por DNI ──► JWT de Alimentarte
```

## Variables en `.env`

| Variable | Uso |
|---|---|
| `ALIMENTARTE_SSO_SECRET` | Secreto compartido HS256 (debe ser **idéntico** en Alimentarte: `Sso__Secret`) |
| `ALIMENTARTE_SSO_URL` | URL del frontend de Alimentarte, por defecto `http://localhost:5173/sso` |
| `ALIMENTARTE_DB_USER` | Rol de solo lectura creado en `guarani3` (default `alimentarte_guarani`) |
| `ALIMENTARTE_DB_PASSWORD` | Clave de ese rol |

El entrypoint de Gestión crea el rol y concede:

```sql
GRANT CONNECT ON DATABASE guarani3 TO alimentarte_guarani;
GRANT USAGE ON SCHEMA negocio TO alimentarte_guarani;
GRANT SELECT ON negocio.mdp_personas, negocio.mdp_personas_contactos,
               negocio.mdp_personas_documentos, negocio.sga_alumnos
  TO alimentarte_guarani;
```

## Alimentarte: cambios aplicados

- `Alimentarte.Infrastructure/Auth/GuaraniAuthService.cs` — valida DNI/clave contra Guaraní.
- `Alimentarte.API/Controllers/AuthController.cs`:
  - `POST /api/auth/login-guarani` `{ dni, password }`
  - `POST /api/auth/sso` `{ token }`
- `Alimentarte.API/Program.cs` — registra `GuaraniAuthService`.
- `Alimentarte.API/appsettings.json` — secciones `ConnectionStrings:Guarani` y `Sso`.
- Frontend: pestaña **Alumno IUPA** en el login, página `/sso` y API `loginGuarani`/`sso`.

Variables de entorno para correr la API:

```bash
export ConnectionStrings__Guarani='Host=localhost;Port=5434;Database=guarani3;Username=alimentarte_guarani;Password=alimentarte123;Search Path=negocio;SSL Mode=Disable'
export Sso__Secret='cambiar-secreto-compartido-alimentarte-3w-2026'
```

> El valor de `Sso__Secret` debe coincidir con `ALIMENTARTE_SSO_SECRET` de este compose.

## Personalización en 3w

Siguiendo la [documentación de personalización Chulupi](https://documentacion.siu.edu.ar/wiki/SIU-Guarani/Version3.23.0/personalizaciones/personalizacion_chulupi)
y la [creación de operaciones en 3w](https://documentacion.siu.edu.ar/wiki/SIU-Guarani/Version3.23.0/personalizaciones/creacion_operacion_3w):

```
3w-pers/iupa/
├── conf/acceso/acc_Alumno.php            # operación "alimentarte" visible en el menú
├── mensajes/mensajes.es.php              # etiqueta "Comedor Universitario (Alimentarte)"
└── operaciones/
    ├── alimentarte/                      # firma el JWT y redirige
    └── inicio_alumno/                    # botón en el inicio del alumno
```

`Dockerfile.3w` copia este árbol a `src/pers/iupa`, fuera del checkout SVN.
`docker/entrypoint-3w.sh` activa la personalización en `config.php`:

```php
'usar_personalizaciones' => true,
'personalizacion' => 'iupa'
```

El token se manda en el **fragmento** (`#token=...`): no viaja al servidor ni aparece en el `Referer`.

## DNI y mapeo

- Se normaliza el DNI a solo dígitos.
- Se busca en `mdp_personas.usuario` (en IUPA el usuario es el DNI) y, como respaldo, en
  `mdp_personas_documentos` con `tipo_documento = 0` (DNI).
- Se considera alumno si tiene perfil `Cursos`/`Preinscripcion` o un registro en
  `sga_alumnos`.
- Si el DNI no existe en Alimentarte → **404 `no_postulado`**, sin crear nada.
- Si la persona está bloqueada en Guaraní o no tiene clave → se rechaza.

## Verificación ya realizada

- `POST /api/auth/login-guarani` con DNI/clave correctos → JWT `rol=Alumno`.
- Clave incorrecta → 401; DNI de Guaraní sin inscripción en Alimentarte → 404 `no_postulado`.
- Token firmado con `firebase/php-jwt` desde el contenedor 3w → `POST /api/auth/sso` → JWT.
- Token inválido → 401.
- `php -l` de todos los archivos de la personalización → sin errores.
- `dotnet build` y `npm run build` de Alimentarte → correctos.

## Producción

- Usar HTTPS en Guaraní 3w y en Alimentarte; configurar `ALIMENTARTE_SSO_URL` con el dominio real.
- Cambiar `ALIMENTARTE_SSO_SECRET` / `Sso__Secret` por un valor aleatorio largo.
- Agregar el dominio real de Alimentarte a `Cors:AllowedOrigins`.
- Rotar las claves de los usuarios admin; el rol de BD de Guaraní sigue siendo solo lectura.
