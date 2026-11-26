-- Vista equivalente a co_araucano::get_nominal_estudiantes_ingreso()
-- Réplica del SELECT de
--   src/php/nucleo/administracion/araucano/co_araucano.php:311-409
-- para Guaraní 3.23.0 (nodo iupa).
--
-- La vista trae todos los años académicos. Para ver el mismo resultado que
-- la operación "Información Nominal de Estudiantes de Ingreso a SIU-Araucano":
--
--   SELECT * FROM negocio.vw_araucano_estudiantes_ingreso
--    WHERE anio_academico = 2026;              -- y opcionalmente:
--          AND responsable_academica = 5;
--
-- Las columnas y su orden son los del archivo que genera la operación
-- (temp/araucano/estudiantes_ingreso/<anio>/archivo_ingreso.txt).
-- Se agregan al final anio_academico y responsable_academica para poder filtrar.
--
-- Ojo: requisitos_academicos queda en 5 ("sin requisito académico"), que es
-- lo que hace el SQL. El PHP después puede cambiarlo a 1 (sí) o 2 (no) según
-- la relación con un curso de ingreso (co_propuestas_relaciones +
-- propuesta::validar_relacion); esa lógica no se puede replicar en una vista.

CREATE OR REPLACE VIEW negocio.vw_araucano_estudiantes_ingreso AS
SELECT DISTINCT
       mdp_personas_documentos.tipo_documento,
       mdp_personas_documentos.nro_documento,
       cuit.nro_documento                                             AS cuit,
       mdp_personas_sexo.codigo_araucano                              AS genero,
       to_char(mdp_personas.fecha_nacimiento, 'YYYYMMDD')             AS fecha_nacimiento,
       to_char(sga_propuestas_aspira.fecha_inscripcion, 'YYYYMMDD')   AS fecha_alta_sistema,
       negocio.get_ra_inst_araucano_propuesta(sga_alumnos.propuesta, 'IA')
                                                                      AS institucion_araucano,
       sga_certificados.titulo_araucano                               AS titulo_araucano,
       CASE WHEN sga_situacion_aspirante.resultado_asp = 'A' THEN 1
            ELSE 2 END                                                AS requisitos_administrativos,
       5                                                             AS requisitos_academicos,
       CASE WHEN sga_situacion_aspirante.resultado_asp = 'A' THEN 1
            WHEN sga_situacion_aspirante.resultado_asp = 'R' THEN 2
            ELSE 3 END                                                AS en_condicion_de_ingreso,
       ''::text                                                      AS fecha_finalizacion_curso_ingreso,
       negocio.get_dependencia_araucano_propuesta_ubicacion(
           sga_propuestas_aspira.propuesta, sga_propuestas_aspira.ubicacion)
                                                                      AS dependencia_ingreso,
       CASE WHEN mdp_personas.nacionalidad = 2 THEN 888888888
            WHEN sga_propuestas_aspira.tipo_ingreso = 3 THEN 777777777
            ELSE COALESCE((
                    SELECT sga_colegios_secundarios.cue
                      FROM negocio.mdp_datos_estudios
                      JOIN negocio.sga_colegios_secundarios
                        ON sga_colegios_secundarios.colegio = mdp_datos_estudios.colegio
                     WHERE mdp_datos_estudios.persona = mdp_personas.persona
                       AND mdp_datos_estudios.nivel_estudio = 3
                     ORDER BY mdp_datos_estudios.fecha_egreso DESC
                     LIMIT 1
                 ), 999999999)
       END                                                           AS cue_escuela_origen,
       negocio.get_horas_trabajo_araucano(
           mdp_personas.persona,
           to_date('01/04/' || sga_propuestas_aspira.anio_academico::text, 'DD/MM/YYYY'))
                                                                      AS horas_trabajo,
       negocio.get_nivel_instruccion_araucano(
           mdp_personas.persona,
           to_date('01/04/' || sga_propuestas_aspira.anio_academico::text, 'DD/MM/YYYY'),
           'P')                                                       AS nivel_instruccion_padre,
       negocio.get_nivel_instruccion_araucano(
           mdp_personas.persona,
           to_date('01/04/' || sga_propuestas_aspira.anio_academico::text, 'DD/MM/YYYY'),
           'M')                                                       AS nivel_instruccion_madre,
       COALESCE(negocio.get_pais_localidad(mdp_personas.localidad_nacimiento), 99999)
                                                                      AS pais_nacimiento,
       COALESCE(negocio.get_pais_localidad(his_datos_personales.procedencia_localidad), 99999)
                                                                      AS pais_procedencia,
       CASE WHEN (mdp_personas.nacionalidad = 2
                  OR negocio.get_pais_localidad(his_datos_personales.procedencia_localidad) <> 54)
                 THEN COALESCE(to_char(mdp_personas.fecha_ingreso_pais, 'YYYYMMDD'), '99999999')
            WHEN negocio.get_pais_localidad(his_datos_personales.procedencia_localidad) = 54
                 THEN COALESCE(to_char(mdp_personas.fecha_ingreso_pais, 'YYYYMMDD'), '99999999')
            ELSE ''
       END                                                           AS fecha_ingreso_pais,
       CAST(COALESCE(negocio.get_titulo_institucion_habilitante(sga_alumnos.alumno, 7), '99999')
            AS integer)                                               AS pais_titulo_anterior,
       his_datos_personales.procedencia_localidad,
       COALESCE(mdp_personas.identidad_genero, 0)                     AS identidad_genero,
       CASE WHEN mdp_personas.identidad_genero = 13
            THEN mdp_personas.identidad_genero_otro::text
            ELSE ''::text END                                         AS identidad_genero_otro,
       mdp_personas.pueblo_originario,
       mdp_personas.pueblo_originario_otro,
       COALESCE(his_datos_discapacidad.condicion_discapacidad, 'N')   AS condicion_discapacidad,
       COALESCE(his_datos_discapacidad.tiene_cud, 'N')                AS tiene_cud,
       COALESCE(his_datos_discapacidad.disc_auditiva, 'N')            AS disc_auditiva,
       COALESCE(his_datos_discapacidad.disc_visual, 'N')              AS disc_visual,
       COALESCE(his_datos_discapacidad.disc_motora, 'N')              AS disc_motora,
       COALESCE(his_datos_discapacidad.disc_cond_psicosocial, 'N')    AS disc_cond_psicosocial,
       COALESCE(his_datos_discapacidad.disc_otra, 'N')                AS disc_otra,
       COALESCE(regexp_replace(his_datos_discapacidad.otra_descripcion,
                               E'[\\n\\r]+', ' ', 'g'), '')           AS disc_otra_descripcion,
       sga_alumnos.alumno,
       mdp_personas.persona,
       sga_propuestas.propuesta,
       sga_alumnos.plan_version,
       sga_certificados.certificado,
       sga_propuestas_aspira.anio_academico,
       (SELECT ra.responsable_academica
          FROM negocio.sga_propuestas_ra ra
         WHERE ra.propuesta = sga_propuestas.propuesta
         ORDER BY ra.responsable_academica
         LIMIT 1)                                                     AS responsable_academica
  FROM negocio.sga_propuestas_aspira
  JOIN negocio.sga_situacion_aspirante
    ON sga_propuestas_aspira.situacion_asp = sga_situacion_aspirante.situacion_asp
  JOIN negocio.sga_propuestas
    ON sga_propuestas_aspira.propuesta = sga_propuestas.propuesta
  JOIN negocio.sga_alumnos
    ON sga_propuestas_aspira.persona = sga_alumnos.persona
   AND sga_propuestas_aspira.propuesta = sga_alumnos.propuesta
  JOIN negocio.mdp_personas
    ON sga_propuestas_aspira.persona = mdp_personas.persona
  JOIN negocio.mdp_personas_sexo
    ON mdp_personas.sexo = mdp_personas_sexo.sexo
  JOIN negocio.mdp_personas_documentos
    ON mdp_personas.documento_principal = mdp_personas_documentos.documento
  JOIN negocio.sga_planes_certificados
    ON sga_alumnos.plan_version = sga_planes_certificados.plan_version
  JOIN negocio.sga_certificados
    ON sga_planes_certificados.certificado = sga_certificados.certificado
  JOIN negocio.sga_certificados_tipos
    ON sga_certificados.certificado_tipo = sga_certificados_tipos.certificado_tipo
  LEFT JOIN negocio.his_datos_personales
    ON his_datos_personales.dato_censal_per = negocio.get_dato_censal_personal(
           mdp_personas.persona,
           to_date('01/04/' || sga_propuestas_aspira.anio_academico::text, 'DD/MM/YYYY'))
  LEFT JOIN negocio.his_datos_discapacidad
    ON his_datos_discapacidad.dato_censal_disc = negocio.get_dato_censal_discapacidad(
           mdp_personas.persona,
           to_date('01/04/' || sga_propuestas_aspira.anio_academico::text, 'DD/MM/YYYY'))
  LEFT JOIN negocio.mdp_personas_documentos AS cuit
    ON cuit.persona = mdp_personas.persona
   AND cuit.tipo_documento = 3
 WHERE sga_propuestas.propuesta_tipo <> 202
   AND sga_certificados.titulo_nivel = 'FINAL'
   AND sga_certificados.titulo_araucano IS NOT NULL
   AND sga_certificados.informar_araucano = 'S'
   AND sga_certificados_tipos.es_titulo = 'S';
