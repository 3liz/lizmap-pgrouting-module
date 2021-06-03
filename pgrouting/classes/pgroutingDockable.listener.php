<?php
    class pgroutingDockableListener extends jEventListener
    {
        public function onmapDockable($event)
        {
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
                ['type' => 'module']
            );
            $event->add($dock);
        }
    }
