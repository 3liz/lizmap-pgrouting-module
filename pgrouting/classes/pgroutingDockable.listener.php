<?php

use PgRouting\CheckConfig;

/**
 * @author    3Liz
 * @copyright 2021 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class pgroutingDockableListener extends jEventListener
{
    public function onmapDockable($event)
    {
        // get repository and project
        $repository = $event->repository;
        $project = $event->project;

        // implement new object
        $checkConfig = new CheckConfig($repository, $project, 'pgrouting');

        // check extension in database
        $checkResult = $checkConfig->allCheck();
        // if result = 0 it's false
        if ($checkResult['code'] == 0) {
            foreach ($checkResult['message'] as $value) {
                jLog::log($value, 'error');
            }
        } else {
            // Project name must contain 'pgrouting' to enable the module
            // OR the QGIS project variable lizmap_pgrouting_enabled must be yes
            $p = \lizmap::getProject($repository . '~' . $project);
            $customVariables = $p->getCustomProjectVariables();
            if (strpos($project, 'pgrouting') !== false || (
                array_key_exists('lizmap_pgrouting_enabled', $customVariables)
                && strtolower(trim($customVariables['lizmap_pgrouting_enabled'])) == 'yes'
            )) {
                $bp = jApp::urlBasePath();
                // dock
                $content = '<lizmap-pgrouting></lizmap-pgrouting>';
                $dock = new lizmapMapDockItem(
                    'pgrouting',
                    \jLocale::get('pgrouting~dictionary.dock.title'),
                    $content,
                    99,
                    $bp . 'pgrouting/css/pgrouting.css',
                    $bp . 'pgrouting/js/pgrouting.umd.js'
                );
                $event->add($dock);
            }
        }
    }
}
