<?php
// Genera config.php y alias.conf a partir de las plantillas del SVN.
// Se usa str_replace en lugar de sed para no romper claves con &, # o \.

$root = '/opt/preinscripcion';

$configFile = "$root/instalacion/config.php";
$config = file_get_contents($configFile);

$pto = getenv('PREINSCRIPCION_PTO');
$reemplazos = [
    'nombre_base_preinscripcion'  => getenv('PREINSCRIPCION_DB'),
    'host_base_preinscripcion'    => getenv('DB_HOST'),
    'puerto_base_preinscripcion'  => getenv('DB_PORT'),
    'usuario_base_preinscripcion' => getenv('DB_USER'),
    'password_base_preinscripcion' => getenv('DB_PASSWORD'),
    'nombre_base_gestion'         => getenv('GESTION_DB'),
    'schema_base_gestion'         => 'negocio',
    'host_base_gestion'           => getenv('DB_HOST'),
    'puerto_base_gestion'         => getenv('DB_PORT'),
    'usuario_base_gestion'        => getenv('DB_USER'),
    'password_base_gestion'       => getenv('DB_PASSWORD'),
    '[id_pto_acc]'                => $pto,
    'https://www.universidad.edu.ar/preinscripcion' => getenv('URL_PREINSCRIPCION'),
    "'email_ayuda' => '',"        => "'email_ayuda' => '" . getenv('AUTOGESTION_EMAIL_AYUDA') . "',",
];

$config = str_replace(array_keys($reemplazos), array_values($reemplazos), $config);

// Desactivar reCAPTCHA: no hay keys en un entorno local.
$config = preg_replace("/('captcha'\s*=>\s*\[.*?'activo'\s*=>\s*)true/s", '${1}false', $config, 1);

file_put_contents($configFile, $config);

$aliasFile = "$root/instalacion/alias.conf";
$alias = file_get_contents($aliasFile);
$alias = str_replace(
    ['/path/a/preinscripcion', '[pto_acc]', '[id_pto_acc]'],
    [$root, $pto, $pto],
    $alias
);
file_put_contents($aliasFile, $alias);

echo "config.php y alias.conf configurados (punto de acceso: $pto)\n";
