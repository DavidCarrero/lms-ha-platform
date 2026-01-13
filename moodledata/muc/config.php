<?php defined('MOODLE_INTERNAL') || die();
$configuration = array(
    'stores' => array(
        'default_application' => array(
            'name' => 'default_application',
            'plugin' => 'redis',
            'configuration' => array(
                'server' => 'redis',
                'prefix' => 'mdl_',
                'serializer' => 1
            ),
            'features' => 14,
            'modes' => 1,
            'default' => true
        ),
        'default_session' => array(
            'name' => 'default_session',
            'plugin' => 'redis',
            'configuration' => array(
                'server' => 'redis',
                'prefix' => 'mdl_sess_',
                'serializer' => 1
            ),
            'features' => 14,
            'modes' => 2,
            'default' => true
        ),
        'default_request' => array(
            'name' => 'default_request',
            'plugin' => 'static',
            'configuration' => array(),
            'features' => 31,
            'modes' => 4,
            'default' => true
        )
    ),
    'modemappings' => array(
        array(
            'mode' => 1,
            'store' => 'default_application'
        ),
        array(
            'mode' => 2,
            'store' => 'default_session'
        ),
        array(
            'mode' => 4,
            'store' => 'default_request'
        )
    ),
    'definitions' => array(),
    'locks' => array(
        'default_file_lock' => array(
            'name' => 'cachelock_file_default',
            'type' => 'cachelock_file',
            'dir' => 'filelocks',
            'default' => true
        )
    )
);
