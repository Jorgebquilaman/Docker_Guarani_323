<?php

namespace iupa\operaciones\inicio_alumno;

use SIU\Chulupi\kernel;

/**
 * Agrega la URL de la operación de Alimentarte al pagelet del inicio del alumno.
 */
class pagelet_lista_carreras extends \siu\operaciones\inicio_alumno\pagelet_lista_carreras
{
    function prepare()
    {
        parent::prepare();
        $this->data['url_alimentarte'] = kernel::vinculador()->crear('alimentarte', 'index');
    }
}
