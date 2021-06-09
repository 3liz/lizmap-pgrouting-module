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