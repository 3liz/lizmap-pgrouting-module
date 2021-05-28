// PgRouting

class pgRouting {

    constructor() {
        lizMap.events.on({
            uicreated: () => {
                // Init draw with 2 points and hide layer
                lizMap.mainLizmap.draw.init('Point', 2);
                lizMap.mainLizmap.draw.visible = false;

                lizMap.mainEventDispatcher.addListener(() => {
                    const features = lizMap.mainLizmap.draw.features;
                    if (features.length === 2) {
                        this._getRoute(
                            features[0].getGeometry().getCoordinates(),
                            features[1].getGeometry().getCoordinates()
                        );
                    }
                }, ['draw.addFeature']
                );

                // TODO: add dispatch 'modifyend' event in Draw class
                lizMap.mainLizmap.draw._modifyInteraction.on('modifyend', () => {
                    const features = lizMap.mainLizmap.draw.features;
                    if (features.length === 2) {
                        this._getRoute(
                            features[0].getGeometry().getCoordinates(),
                            features[1].getGeometry().getCoordinates()
                        );
                    }
                });
            },
            dockopened: (evt) => {
                if (evt.id === "pgrouting") {
                    lizMap.mainLizmap.draw.visible = true;
                }
            },
            dockclosed: (evt) => {
                if (evt.id === "pgrouting") {
                    lizMap.mainLizmap.draw.visible = false;
                }
            }
        });
    }

    _getRoute(start, end) {

    }
}

lizMap.pgRouting = new pgRouting();
