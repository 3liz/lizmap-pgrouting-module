import { Circle as CircleStyle, Fill, Stroke, Text, Style } from 'ol/style';
import GeoJSON from 'ol/format/GeoJSON';
import { Vector as VectorSource } from 'ol/source';
import { Vector as VectorLayer } from 'ol/layer';
import { Draw , Modify } from 'ol/interaction.js';
import { altKeyOnly } from 'ol/events/condition.js';
import Feature from 'ol/Feature.js';
import Point from 'ol/geom/Point.js';
import { html, render } from 'lit-html';

class pgRouting extends HTMLElement {

    constructor() {
        super();
    }

    connectedCallback() {
        // Get locales
        this._locales = '';

        this._mergedRoads = [];
        this._POIFeatures = [];

        this._mainTemplate = () => html`
            <div class="menu-content">
                <p>${this._locales['draw.message']}</p>
                <div class="commands">
                    <button class="btn" @click=${ () => this.restartDraw()}>
                        <svg width="18" height="18">
                            <use xlink:href="#refresh" />
                        </svg>
                    </button>
                </div>
                <div class="pgrouting">
                    ${this._mergedRoads.length > 0 ? html`
                    <div class="roadmap">
                        <h4>${this._locales['roadmap.title']}</h4>
                        <dl>
                            ${this._mergedRoads.map((road) => html`<dt>${road.label ? road.label : this._locales['road.label.missing']}</dt><dd>${road.distance < 1 ? 1 : Math.round(road.distance)}m</dd>`)}
                        </dl>
                    </div>`: ''
                    }
                    ${this._POIFeatures.length > 0 ? html`
                    <div class="poi">
                        <h4>${this._locales['poi.title']}</h4>
                        <dl>
                            ${this._POIFeatures.map((feature) => html`<dt>${feature.properties.label}</dt><dd>${feature.properties.description}</dd><dd>${feature.properties.type}</dd>`)}
                        </dl>
                    </div>`: ''
                    }
                </div>
            </div>`;


        fetch(`${lizUrls.basepath}index.php/pgrouting/translate/`)
            .then((response) => {
                return response.json();
            })
            .then((json) => {
                if (json) {
                    this._locales = JSON.parse(json);
                    render(this._mainTemplate(), this);
                }
            });

        render(this._mainTemplate(), this);

        lizMap.events.on({
            uicreated: () => {
                this.initDraw();
                this.toggleDrawVisibility(false);
            },
            dockopened: (evt) => {
                if (evt.id === "pgrouting") {
                    lizMap.mainLizmap.newOlMap = true;
                    this.toggleDrawVisibility(true);
                }
            },
            dockclosed: (evt) => {
                if (evt.id === "pgrouting") {
                    lizMap.mainLizmap.newOlMap = false;
                    this.toggleDrawVisibility(false);
                }
            }
        });
    }

    disconnectedCallback() {
    }

    initDraw() {
        this._milestoneRouteMap = new Map();

        // Init milestones draw
        const milestoneSource = new VectorSource({
            useSpatialIndex: false
        });

        // Refresh route only when user add a feature
        // Not when we programmaticaly add a feature
        this._userAddFeature = true;
        milestoneSource.on('addfeature', event => {
            if (this._userAddFeature) {
                this._refreshRoute(event.feature, 'add');
            }
        });

        this._drawInteraction = new Draw({
            source: milestoneSource,
            type: "Point",
        });

        this._modifyMilestone = new Modify({
            source: milestoneSource,
            deleteCondition: evt => {
                if(evt.type === 'singleclick' && altKeyOnly(evt)){
                    const features = lizMap.mainLizmap.map.getFeaturesAtPixel(evt.pixel, {
                        layerFilter: layer => {
                            return layer === this._milestoneLayer;
                        },
                        hitTolerance: 8
                    });
                    this._refreshRoute(features[0], 'delete');
                    this._milestoneLayer.getSource().removeFeature(features[0]);
                }
                return false;
            }
        });

        this._modifyMilestone.on('modifyend', event => {
            this._refreshRoute(event.features.item(0), 'modify');
        });

        this._milestoneLayer = new VectorLayer({
            source: milestoneSource,
            style: (feature) => {
                const milestoneFeatures = this._milestoneLayer.getSource().getFeaturesCollection().getArray();
                const featureIndex = milestoneFeatures.indexOf(feature);
                let fillColor = 'blue';
                let labelText = '';
    
                // Start is green, end is red and intermediates are blue
                if (featureIndex === 0) {
                    fillColor = 'green';
                } else if (featureIndex === milestoneFeatures.length - 1) {
                    fillColor = 'red';
                } else {
                    labelText = featureIndex.toString();
                }
                return new Style({
                    image: new CircleStyle({
                        radius: 10,
                        fill: new Fill({
                            color: fillColor,
                        }),
                    }),
                    text: new Text({
                        text: labelText,
                        font: 'bold 18px sans-serif',
                        fill: new Fill({
                            color: 'white',
                        })
                    })
                });
            }
        });

        // Display route
        const routeSource = new VectorSource();

        this._modifyRoute = new Modify({
            source: routeSource
        });

        this._modifyRoute.on('modifyend', event => {
            const modifiedFeature = event.features.item(0);
            const coords = event.mapBrowserEvent.coordinate;

            this._milestoneRouteMap.forEach((routeFeatures, milestoneFeatures) => {
                for (const routeFeature of routeFeatures) {
                    if (modifiedFeature === routeFeature) {
                        // Remove and replace milestone features to add the new one
                        const oldMilestoneFeatures = this._milestoneLayer.getSource().getFeatures();
                        this._milestoneLayer.getSource().clear();

                        const newFeature = new Feature({
                            geometry: new Point(coords)
                        });

                        // Avoid 'addfeature' callback
                        this._userAddFeature = false;
                        const newMilestoneFeatures = Array.from(oldMilestoneFeatures);

                        oldMilestoneFeatures.forEach((oldMilestoneFeature, index) => {
                            if(oldMilestoneFeature === milestoneFeatures[0]){
                                newMilestoneFeatures.splice(index + 1, 0, newFeature);
                                return;
                            }
                        });

                        this._milestoneLayer.getSource().addFeatures(newMilestoneFeatures);
                        this._userAddFeature = true;

                        // Remove previous routes mapped to the milestone feature
                        const oldRouteFeatures = this._milestoneRouteMap.get(milestoneFeatures);

                        for (const routeFeature of oldRouteFeatures) {
                            this._routeLayer.getSource().removeFeature(routeFeature);
                        }

                        this._milestoneRouteMap.delete(milestoneFeatures);

                        this._getRoute(
                            milestoneFeatures[0],
                            newFeature
                        );

                        this._getRoute(
                            newFeature,
                            milestoneFeatures[1]
                        );
                        return;
                    }
                }
            });
        });

        const width = 8;
        this._routeLayer = new VectorLayer({
            source: routeSource,
            style: [
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
            ],
        });

        // Interaction's order matters. We priorize milestones modification
        lizMap.mainLizmap.map.addInteraction(this._drawInteraction);
        lizMap.mainLizmap.map.addInteraction(this._modifyRoute);
        lizMap.mainLizmap.map.addInteraction(this._modifyMilestone);

        lizMap.mainLizmap.map.addLayer(this._routeLayer);
        lizMap.mainLizmap.map.addLayer(this._milestoneLayer);

        // Show mouse pointer when hovering origin or destination points
        lizMap.mainLizmap.map.on('pointermove', (e) => {
            if (e.dragging) {
                return;
            }
            const pixel = lizMap.mainLizmap.map.getEventPixel(e.originalEvent);
            const featuresAtPixel = lizMap.mainLizmap.map.getFeaturesAtPixel(pixel);
            const featureHover = featuresAtPixel.some(feature => this._milestoneLayer.getSource().getFeatures().includes(feature));

            lizMap.mainLizmap.map.getViewport().style.cursor = featureHover ? 'pointer' : '';
        });
    }

    restartDraw() {
        this._milestoneRouteMap.clear();
        this._routeLayer.getSource().clear();
        this._milestoneLayer.getSource().clear();

        this._mergedRoads = [];
        this._POIFeatures = [];

        render(this._mainTemplate(), this);
    }

    toggleDrawVisibility(visible){
        if (this._milestoneLayer) {
            this._milestoneLayer.setVisible(visible);
        }

        if (this._routeLayer) {
            this._routeLayer.setVisible(visible);
        }
    }

    _refreshRoute(changedFeature, change) {
        const milestoneFeatures = this._milestoneLayer.getSource().getFeaturesCollection().getArray();
        const featuresLength = milestoneFeatures.length;

        if (change === 'add') {
            if (featuresLength > 1) {
                this._getRoute(
                    milestoneFeatures[featuresLength - 2],
                    milestoneFeatures[featuresLength - 1]
                );
            }
        } else {
            milestoneFeatures.forEach((feature, index) => {
                if (changedFeature === feature) {
                    // Remove previous routes mapped to the milestone feature
                    this._milestoneRouteMap.forEach((routeFeatures, milestoneFeatures) => {
                        if (milestoneFeatures.includes(changedFeature)) {
                            for (const routeFeature of routeFeatures) {
                                this._routeLayer.getSource().removeFeature(routeFeature);
                            }
                            this._milestoneRouteMap.delete(milestoneFeatures);
                        }
                    });

                    if (change === 'modify') {
                        // Refresh route from changedFeature to previous feature
                        if (index !== 0) {
                            this._getRoute(
                                milestoneFeatures[index - 1],
                                changedFeature
                            );
                        }
                        // Refresh route from changedFeature to next feature
                        if (index !== featuresLength - 1) {
                            this._getRoute(
                                changedFeature,
                                milestoneFeatures[index + 1]
                            );
                        }
                    } else if (change === 'delete') {
                        // Deletion of intermediate milestones
                        if (index !== 0 && index !== featuresLength - 1) {
                            this._getRoute(
                                milestoneFeatures[index - 1],
                                milestoneFeatures[index + 1]
                            );
                        } else { // Deletion of start or end milestone. No need to query
                            this._refreshRoadMap();
                        }
                    }
                }
            });
        }
    }

    _getRoute(originFeature, destinationFeature) {

        const origin = lizMap.mainLizmap.transform(originFeature.getGeometry().getCoordinates(), lizMap.mainLizmap.projection, 'EPSG:4326');
        const destination = lizMap.mainLizmap.transform(destinationFeature.getGeometry().getCoordinates(), lizMap.mainLizmap.projection, 'EPSG:4326');

        fetch(`${lizUrls.basepath}index.php/pgrouting/?repository=${lizUrls.params.repository}&project=${lizUrls.params.project}&origin=${origin[0]},${origin[1]}&destination=${destination[0]},${destination[1]}&crs=4326&option=get_short_path`)
            .then((response) => {
                return response.json();
            })
            .then((json) => {
                // Remove route if any and create new one
                this._POIFeatures = [];

                if (json?.routing?.features) {

                    // Remove `id` property as there is collision
                    for (const feature of json.routing.features) {
                        delete feature.id;
                    }

                    const routeFeatures = new GeoJSON().readFeatures(json.routing, {
                        dataProjection: 'EPSG:4326',
                        featureProjection: lizMap.mainLizmap.projection
                    });
                    this._routeLayer.getSource().addFeatures(routeFeatures);

                    this._milestoneRouteMap.set([originFeature, destinationFeature], routeFeatures);

                    this._refreshRoadMap();
                    // Get POIs    
                    this._POIFeatures = json?.poi?.features ?? [];
                } else {
                    lizMap.addMessage(this._locales['route.error'], 'error', true)
                }
            });
    }

    _refreshRoadMap() {
        this._mergedRoads = [];

        this._milestoneLayer.getSource().getFeaturesCollection().forEach((milestone, index, milestones) => {
            this._milestoneRouteMap.forEach((routeFeatures, milestoneFeatures) => {
                if (milestoneFeatures[0] === milestone && milestoneFeatures[1] === milestones[index + 1]) {
                    // Get roadmap
                    // Merge road with same label when sibling
                    let mergedRoads = [];
                    let previousLabel = '';

                    for (const feature of routeFeatures) {
                        const label = feature.get('label');
                        const distance = feature.get('dist');

                        if (label !== previousLabel) {
                            mergedRoads.push({ label: label, distance: distance });
                        } else {
                            mergedRoads[mergedRoads.length - 1] = { label: label, distance: distance + mergedRoads[mergedRoads.length - 1].distance }
                        }
                        previousLabel = label;
                    }

                    this._mergedRoads = this._mergedRoads.concat(mergedRoads);
                    return;
                }
            });
        });
        render(this._mainTemplate(), this);
    }
}

window.customElements.define('lizmap-pgrouting', pgRouting);
