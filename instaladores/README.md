# Instaladores RAR

Colocar aquí los instaladores descargados del Portal de Servicios de Comunidad del SIU:

```
instaladores/instalador_kolla_4.10.3.rar
instaladores/instalador_tehuelche_4.5.2.rar
```

Los scripts `scripts/05-extraer-kolla.sh` y `scripts/06-extraer-tehuelche.sh` buscan
primero en esta carpeta y, si no están, en la raíz del proyecto.

Los archivos `*.rar` están ignorados por Git: **nunca se suben al repositorio**. Cada
persona que clone el proyecto debe descargarlos por su cuenta.
