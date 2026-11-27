<?php

namespace iupa\operaciones\alimentarte;

use Firebase\JWT\JWT;
use SIU\Chulupi\kernel;
use siu\extension_kernel\controlador_g3w2;

/**
 * Genera un token de SSO para Alimentarte y redirige al frontend.
 * El token se envía en el fragmento (#) para que no viaje en el Referer ni en logs.
 */
class controlador extends controlador_g3w2
{
    function modelo()
    {
        return null;
    }

    function accion__index()
    {
        $secreto = getenv('ALIMENTARTE_SSO_SECRET');
        $url = getenv('ALIMENTARTE_SSO_URL');

        if (empty($secreto) || empty($url)) {
            kernel::log()->add_error('Faltan ALIMENTARTE_SSO_SECRET o ALIMENTARTE_SSO_URL');
            echo 'No se pudo iniciar sesión en Alimentarte. Contacte al comedor universitario.';
            exit;
        }

        $persona = (int) kernel::sesion()->get_id_persona();
        if ($persona <= 0) {
            kernel::log()->add_error('No hay persona logueada al generar SSO para Alimentarte');
            echo 'Debe ingresar a Guaraní 3w para usar el Comedor Universitario.';
            exit;
        }

        $sql = "SELECT p.usuario AS usuario, c.email AS email, d.nro_documento AS dni
                  FROM negocio.mdp_personas p
                  LEFT JOIN negocio.mdp_personas_contactos c
                         ON c.persona = p.persona AND c.contacto_tipo = 'MP'
                  LEFT JOIN negocio.mdp_personas_documentos d
                         ON d.persona = p.persona AND d.tipo_documento = 0
                 WHERE p.persona = " . $persona;
        $datos = kernel::db()->consultar_fila($sql);

        $dni = !empty($datos['dni']) ? preg_replace('/\D/', '', $datos['dni']) : '';
        if ($dni === '' && !empty($datos['usuario'])) {
            $dni = preg_replace('/\D/', '', $datos['usuario']);
        }

        if ($dni === '') {
            kernel::log()->add_error('No se pudo resolver el DNI para el SSO de Alimentarte');
            echo 'No se pudo identificar al alumno. Contacte al comedor universitario.';
            exit;
        }

        $ahora = time();
        $payload = [
            'iss' => 'guarani3w',
            'aud' => 'alimentarte',
            'sub' => (string) $persona,
            'dni' => $dni,
            'email' => isset($datos['email']) ? $datos['email'] : '',
            'iat' => $ahora,
            'exp' => $ahora + 120,
        ];

        $token = JWT::encode($payload, $secreto, 'HS256');
        // Los vínculos a esta operación llevan la clase 'no-ajax' (ver personalización
        // iupa), así que llega como navegación completa y el Location funciona sin CORS.
        header('Location: ' . rtrim($url, '/') . '#token=' . $token);
        exit;
    }
}
