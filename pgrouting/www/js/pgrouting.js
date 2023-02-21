import { Circle as CircleStyle, Fill, Stroke, Style } from 'ol/style';
import GeoJSON from 'ol/format/GeoJSON';
import { Vector as VectorSource } from 'ol/source';
import { Vector as VectorLayer } from 'ol/layer';
import { Draw , Modify } from 'ol/interaction.js';
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

        this.restartDraw();

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
        if (this._routeLayer) {
            lizMap.mainLizmap.layers.removeLayer(this._routeLayer);
        }

        if (this._milestoneLayer) {
            lizMap.mainLizmap.layers.removeLayer(this._milestoneLayer);
        }

        this._mergedRoads = [];
        this._POIFeatures = [];

        // Init milestones draw
        this._drawSource = new VectorSource({
            useSpatialIndex: false
        });

        this._drawSource.on('addfeature', () => {
            const features = this._drawSource.getFeaturesCollection().getArray();
            const featuresLength = features.length;

            features.forEach((feature, index) => {
                if (index === 0) {
                    feature.set('position', 'origin', true);
                } else if (index === featuresLength - 1) {
                    feature.set('position', 'destination', true);
                } else {
                    feature.set('position', '', true);
                }
            });

            if (featuresLength > 1) {
                this._getRoute(
                    lizMap.mainLizmap.transform(features[featuresLength - 2].getGeometry().getCoordinates(), lizMap.mainLizmap.projection, 'EPSG:4326'),
                    lizMap.mainLizmap.transform(features[featuresLength - 1].getGeometry().getCoordinates(), lizMap.mainLizmap.projection, 'EPSG:4326')
                );
            }
        });

        this._drawInteraction = new Draw({
            source: this._drawSource,
            type: "Point",
        });

        this._modifyInteraction = new Modify({ source: this._drawSource });

        lizMap.mainLizmap.map.addInteraction(this._drawInteraction);
        lizMap.mainLizmap.map.addInteraction(this._modifyInteraction);
        
        this._milestoneLayer = new VectorLayer({
            source: this._drawSource,
            style: (feature) => {
                let fillColor = 'blue';
    
                if (feature.get('position') === 'origin') {
                    fillColor = 'green';
                } else if (feature.get('position') === 'destination') {
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
            }
        });

        lizMap.mainLizmap.map.addLayer(this._milestoneLayer);

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

    _getRoute(origin, destination) {
        fetch(`${lizUrls.basepath}index.php/pgrouting/?repository=${lizUrls.params.repository}&project=${lizUrls.params.project}&origin=${origin[0]},${origin[1]}&destination=${destination[0]},${destination[1]}&crs=4326&option=get_short_path`)
            .then((response) => {
                return response.json();
            })
            .then((json) => {
                // Remove route if any and create new one
                this._mergedRoads = [];
                this._POIFeatures = [];

                if (json?.routing?.features) {

                    for (const feature of json.routing.features) {
                        delete feature.id;
                    }

                    // Display route
                    const width = 8;
                    if(!this._routeLayer){
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
                    } else {
                        const newFeatures = new GeoJSON().readFeatures(json.routing, {
                            dataProjection: 'EPSG:4326',
                            featureProjection: lizMap.mainLizmap.projection
                        });
                        this._routeLayer.getSource().addFeatures(newFeatures);
                    }


                    // Get roadmap
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

                    this._mergedRoads = mergedRoads;

                    // Get POIs    
                    this._POIFeatures = json?.poi?.features ?? [];
                } else {
                    lizMap.addMessage(this._locales['route.error'], 'error', true)
                }

                render(this._mainTemplate(), this);
            });
    }
}

window.customElements.define('lizmap-pgrouting', pgRouting);
