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
                $bp.'assets/pgrouting/pgrouting.css',
                $bp.'assets/pgrouting/pgrouting.js'
            );
            $event->add($dock);
        }
    }
