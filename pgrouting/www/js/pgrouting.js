import { transform } from 'https://cdn.jsdelivr.net/npm/ol@6.5.0/proj.js';
import { Circle as CircleStyle, Fill, Stroke, Style } from 'https://cdn.jsdelivr.net/npm/ol@6.5.0/style.js';

class pgRouting {

    constructor() {
        lizMap.events.on({
            uicreated: () => {
                // Init draw with 2 points and hide layer
                lizMap.mainLizmap.draw.init('Point', 2, true, (feature) => {
                    let fillColor = 'green';

                    if (feature.getId() === 1) {
                        fillColor = 'red';
                    }
                    return new Style({
                        image: new CircleStyle({
                            radius: 10,
                            fill: new Fill({
                                color: fillColor,
                            }),
                        }),
                    });
                });

                lizMap.mainLizmap.draw.visible = false;

                lizMap.mainEventDispatcher.addListener(() => {
                    const features = lizMap.mainLizmap.draw.features;

                    // Add ids to identify origin and destination features for styling
                    if (features.length === 1) {
                        features[0].setId(0);
                    }
                    if (features.length === 2) {
                        features[1].setId(1);
                        this._getRoute(
                            transform(features[0].getGeometry().getCoordinates(), lizMap.mainLizmap.projection, 'EPSG:4326'),
                            transform(features[1].getGeometry().getCoordinates(), lizMap.mainLizmap.projection, 'EPSG:4326')
                        );
                    }
                }, ['draw.addFeature']
                );

                // TODO: add dispatch 'modifyend' event in Draw class
                lizMap.mainLizmap.draw._modifyInteraction.on('modifyend', () => {
                    const features = lizMap.mainLizmap.draw.features;
                    if (features.length === 2) {
                        this._getRoute(
                            transform(features[0].getGeometry().getCoordinates(), lizMap.mainLizmap.projection, 'EPSG:4326'),
                            transform(features[1].getGeometry().getCoordinates(), lizMap.mainLizmap.projection, 'EPSG:4326')
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

    _getRoute(origin, destination) {
        fetch(`${lizUrls.basepath}index.php/pgrouting/?repository=${lizUrls.params.repository}&project=${lizUrls.params.project}&origin=${origin[0]},${origin[1]}&destination=${destination[0]},${destination[1]}&crs=4326&option=get_short_path`)
            .then((response) => {
                return response.json();
            })
            .then((json) => {
                // Remove route if any and create new one
                if (this._routeLayer) {
                    lizMap.mainLizmap.layers.removeLayer(this._routeLayer);
                }

                if (json && json.routing) {
                    // Display route
                    const width = 8;
                    this._routeLayer = lizMap.mainLizmap.layers.addLayerFromGeoJSON(json.routing, undefined, [
                        new Style({
                            stroke: new Stroke({
                                color: 'white',
                                width: width + 4
                            })
                        }),
                        new Style({
                            stroke: new Stroke({
                                color: 'purple',
                                width: width
                            })
                        })
                    ]);

                    // Display roadmap
                    const contentElement = document.querySelector('#pgrouting .menu-content');

                    // Merge road with same label when sibling
                    let mergedRoads = [];
                    let previousLabel = '';

                    for (const feature of json.routing.features) {
                        const label = feature.properties.label;
                        const distance = feature.properties.dist;

                        if (label !== previousLabel) {
                            mergedRoads.push({ label: label, distance: distance });
                        } else {
                            mergedRoads[mergedRoads.length - 1] = { label: label, distance: distance + mergedRoads[mergedRoads.length - 1].distance }
                        }
                        previousLabel = label;
                    }

                    let roadMap = `<dl>`;

                    for (const road of mergedRoads) {
                        roadMap += `<dt>${road.label}</dt><dd>${road.distance < 1 ? 1 : Math.round(road.distance)}m</dd>`;
                    }
                    roadMap += `</dl>`;

                    contentElement.innerHTML = roadMap;
                } else {
                    lizMap.addMessage('No route have been found.', 'error', true)
                }
            });
    }
}

lizMap.pgRouting = new pgRouting();
