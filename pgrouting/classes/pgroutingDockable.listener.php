<?php
    class pgroutingDockableListener extends jEventListener
    {
        public function onmapDockable($event)
        {
            // dock
            $content = '<p>pgrouting</p>';
            $dock = new lizmapMapDockItem(
                'pgrouting',
                '',
                $content,
                9
            );
            $event->add($dock);
        }
    }
