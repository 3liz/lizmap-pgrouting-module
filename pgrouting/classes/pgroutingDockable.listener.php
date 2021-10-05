<?php
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

            //include class to check config
            jClasses::inc('pgrouting~checkConfig');

            //implement new object
            $checkConfig = new checkConfig($repository, $project, 'pgrouting');

            // check extension in database
            $checkResult = $checkConfig->allCheck();
            // if result = 0 it's false
            if ($checkResult['code'] == 0) {
               foreach ($checkResult['message'] as $value) {
                   jLog::log($value, 'error');
               }
            }else{
                // Project name must contains 'pgrouting' to enable the module
                if (strpos($event->project, 'pgrouting') !== false) {
                    $bp = jApp::config()->urlengine['basePath'];
                    // dock
                    $content = '<div class="menu-content"><p>Draw origin and destination points.</p></div>';
                    $dock = new lizmapMapDockItem(
                        'pgrouting',
                        'pgRouting',
                        $content,
                        99,
                        $bp.'assets/pgrouting/css/pgrouting.css',
                        $bp.'assets/pgrouting/js/pgrouting.js',
                        array('type' => 'module')
                    );
                    $event->add($dock);
                }

            }
            
        }
    }
