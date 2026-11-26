-- Se ejecuta solo cuando el volumen de PostgreSQL está vacío.
-- Preinscripción usa su propia base, en LATIN1 (igual que el resto del sistema).
CREATE DATABASE preinscripcion
    ENCODING = 'LATIN1'
    TEMPLATE = template0
    LC_COLLATE = 'C'
    LC_CTYPE = 'C'
    CONNECTION LIMIT = -1;
