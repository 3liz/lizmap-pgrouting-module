<?php
    class pgroutingDockableListener extends jEventListener
    {
        public function onmapDockable($event)
        {
            $bp = jApp::config()->urlengine['basePath'];

            // dock
            $content = '<div class="menu-content"><p>Draw start and end points.</p></div>';
            $dock = new lizmapMapDockItem(
                'pgrouting',
                'pgRouting',
                $content,
                99,
                null,
                $bp.'assets/js/pgrouting.js'
            );
            $event->add($dock);
        }
    }
