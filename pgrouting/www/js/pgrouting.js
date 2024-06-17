class pgRouting extends HTMLElement {

    constructor() {
        super();
    }

    connectedCallback() {
        lizMap.events.on({
            uicreated: () => {
                this.init();
                this.initDraw();
                this.toggleDrawVisibility(false);
            },
            dockopened: (evt) => {
                if (evt.id === "pgrouting") {
                    lizMap.mainLizmap.popup.active = false;
                    this.toggleDrawVisibility(true);
                    lizMap.litHTML.render(this._mainTemplate(), this);
                    // Add tooltip on buttons
                    $('.btn', this).tooltip({
                        placement: 'top'
                    });
                }
            },
            dockclosed: (evt) => {
                if (evt.id === "pgrouting") {
                    lizMap.mainLizmap.popup.active = true;
                    this.toggleDrawVisibility(false);
                }
            }
        });
    }

    disconnectedCallback() {
    }

    init() {
        // Get locales
        this._locales = '';

        this._mergedRoads = [];
        this._POIFeatures = [];

        // Styles
        this._routeLineColor = '#587fc6';
        this._routePointFillColor = 'white';
        this._routeIntermediatePointStrokeColor = '#587fc6';
        this._routeStartPointStrokeColor = 'green';
        this._routeEndPointStrokeColor = 'red';

        // Linestring geometry generated from the whole route
        this._routeGeometry = null;

        this._nodePosition = 0;

        this._mainTemplate = () => lizMap.litHTML.html`
            <div class="menu-content">
                <p>${this._locales['draw.message']}</p>
                <div class="commands">
                    <button class="btn" data-original-title="${this._locales['route.redraw']}" @click=${() => this.restartDraw()}>
                        <svg width="18" height="18">
                            <use xlink:href="#refresh" />
                        </svg>
                    </button>
                    ${lizMap.mainLizmap.featureStorage ? lizMap.litHTML.html`
                    <button class="btn copy-route" ?disabled=${!this._routeLayer.getSource().getFeatures().length} data-original-title="${this._locales['route.copy']}" @click=${() => this.copyToFeatureStorage()}></button>` : ''}
                </div>
                <div class="pgrouting">
                    ${this._mergedRoads.length > 0 ? lizMap.litHTML.html`
                    <div class="roadmap">
                        <h4>${this._locales['roadmap.title']}</h4>
                        <dl>
                            ${this._mergedRoads.map((road) => lizMap.litHTML.html`<dt>${road.label ? road.label : this._locales['road.label.missing']}</dt><dd>${road.distance < 1 ? 1 : Math.round(road.distance)}m</dd>`)}
                        </dl>
                    </div>`: ''
            }
                    ${this._POIFeatures.length > 0 ? lizMap.litHTML.html`
                    <div class="poi">
                        <h4>${this._locales['poi.title']}</h4>
                        <dl>
                            ${this._POIFeatures.map((feature) => lizMap.litHTML.html`<dt>${feature.properties.label}</dt><dd>${feature.properties.description}</dd><dd>${feature.properties.type}</dd>`)}
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
                }
            });
    }

    initDraw() {
        this._milestoneRouteMap = new Map();

        // Init milestones draw
        const milestoneSource = new lizMap.ol.source.Vector({
            useSpatialIndex: false
        });

        // Refresh route only when user add a feature
        // Not when we programmatically add a feature
        this._userAddFeature = true;
        milestoneSource.on('addfeature', event => {
            if (this._userAddFeature) {
                this._refreshRoute(event.feature, 'add');
            }
        });

        this._drawInteraction = new lizMap.ol.interaction.Draw({
            source: milestoneSource,
            type: "Point",
        });

        this._drawInteraction.setActive(false);

        this._modifyMilestone = new lizMap.ol.interaction.Modify({
            source: milestoneSource,
            deleteCondition: evt => {
                if(evt.type === 'singleclick' && lizMap.ol.events.condition.altKeyOnly(evt)){
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

        this._milestoneLayer = new lizMap.ol.layer.Vector({
            visible: false,
            source: milestoneSource,
            style: (feature) => {
                const milestoneFeatures = this._milestoneLayer.getSource().getFeaturesCollection().getArray();
                const featureIndex = milestoneFeatures.indexOf(feature);
                let fillColor = this._routePointFillColor;
                let strokeColor = this._routeIntermediatePointStrokeColor; // pale blue
                let strokeWidth = 3;
                let circleRadius = 12;
                let labelText = '';

                // Start is green, end is red and intermediates are blue
                if (featureIndex === 0) {
                    strokeColor = this._routeStartPointStrokeColor;
                    strokeWidth = 6;
                    circleRadius = 8;
                } else if (featureIndex === milestoneFeatures.length - 1) {
                    strokeColor = this._routeEndPointStrokeColor;
                    strokeWidth = 6;
                    circleRadius = 8;
                } else {
                    labelText = featureIndex.toString();
                }
                return new lizMap.ol.style.Style({
                    image: new lizMap.ol.style.Circle({
                        radius: circleRadius,
                        fill: new lizMap.ol.style.Fill({
                            color: fillColor,
                        }),
                        stroke: new lizMap.ol.style.Stroke({
                            color: strokeColor,
                            width: strokeWidth,
                        }),
                    }),
                    text: new lizMap.ol.style.Text({
                        text: labelText,
                        font: 'bold 14px sans-serif',
                        fill: new lizMap.ol.style.Fill({
                            color: strokeColor,
                        }),
                        offsetY: 1,
                        justify: 'center'
                    })
                });
            }
        });

        // Display route
        const routeSource = new lizMap.ol.source.Vector();

        this._modifyRoute = new lizMap.ol.interaction.Modify({
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

                        const newFeature = new lizMap.ol.Feature({
                            geometry: new lizMap.ol.geom.Point(coords)
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

        this._routeLayer = new lizMap.ol.layer.Vector({
            visible: false,
            source: routeSource,
            style: (feature) => {
                const geometry = feature.getGeometry();
                const styles = [
                    // linestring
                    new lizMap.ol.style.Style({
                        stroke: new lizMap.ol.style.Stroke({
                            color: this._routeLineColor,
                            width: 11,
                        }),
                    }),
                    new lizMap.ol.style.Style({
                        stroke: new lizMap.ol.style.Stroke({
                            color: this._routeLineColor,
                            width: 9,
                        }),
                    }),
                ];

                geometry.forEachSegment((start, end) => {
                    let arrowWidth = 0;
                    let arrowFontSize = 0;
                    // Only show one arrow at every 7 positions
                    if (this._nodePosition % 10 == 0) {
                        arrowWidth = 1;
                        arrowFontSize = 16;
                    }
                    const dx = end[0] - start[0];
                    const dy = end[1] - start[1];
                    const rotation = Math.atan2(dy, dx);

                    // arrows
                    styles.push(
                        new lizMap.ol.style.Style({
                            geometry: new lizMap.ol.geom.Point(end),
                            text: new lizMap.ol.style.Text({
                                text: '>',
                                font: `normal ${arrowFontSize}px sans-serif`,
                                rotateWithView: true,
                                rotation: -rotation,
                                stroke: new lizMap.ol.style.Stroke({
                                    color: 'white',
                                    width: arrowWidth,
                                }),
                                fill: new lizMap.ol.style.Fill({
                                    color: 'white',
                                })
                            })
                        })
                    );

                    this._nodePosition++;
                });

                return styles;
            },
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

    generateFeatureGeometry() {
        // Generate the ordered coordinates of the whole routing complex linestring
        this._routeGeometry = null;
        const coordinates = [];
        let lastPushedCoord;
        for (const milestoneFeature of this._milestoneLayer.getSource().getFeaturesCollection().getArray()) {
            this._milestoneRouteMap.forEach((routeFeatures, milestoneFeatures) => {
                if (milestoneFeatures[0] === milestoneFeature) {
                    for (const routeFeature of routeFeatures) {
                        for (const coord of routeFeature.getGeometry().getCoordinates()) {
                            // Do not add the coordinates if they are equal to the previous ones
                            if (lastPushedCoord && lastPushedCoord[0] == coord[0] && lastPushedCoord[1] == coord[1]) {
                                continue;
                            }
                            lastPushedCoord = coord;
                            coordinates.push(coord);
                        }
                    }

                    return;
                }
            });
        }

        // Save these coordinates as an OpenLayer Linestring geometry
        let olGeometry = new lizMap.ol.geom.LineString(coordinates);

        // Set the variable containing the generated geometry
        this._routeGeometry = olGeometry;
    }

    copyToFeatureStorage() {

        // Generate the OpenLayers geometry from the route parts
        this.generateFeatureGeometry();

        // Save this geometry in Lizmap Storage
        if (this._routeGeometry !== null) {
            lizMap.mainLizmap.featureStorage.set([new lizMap.ol.Feature({
                geometry: this._routeGeometry,
            })], 'pgrouting');
            lizMap.addMessage(this._locales['route.copied'], 'success', true, 1500);
        }
    }

    restartDraw() {
        this._milestoneRouteMap.clear();
        this._routeLayer.getSource().clear();
        this._milestoneLayer.getSource().clear();

        this._mergedRoads = [];
        this._POIFeatures = [];
        this._routeGeometry = null;

        lizMap.litHTML.render(this._mainTemplate(), this);
    }

    toggleDrawVisibility(visible){
        this._drawInteraction.setActive(visible);

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

                            // Send the Lizmap event with the current route geometry
                            this._sendRouteGeometryAsWKT();

                            this._nodePosition = 0;
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

                    const routeFeatures = new lizMap.ol.format.GeoJSON().readFeatures(json.routing, {
                        dataProjection: 'EPSG:4326',
                        featureProjection: lizMap.mainLizmap.projection
                    });

                    this._routeLayer.getSource().addFeatures(routeFeatures);

                    this._milestoneRouteMap.set([originFeature, destinationFeature], routeFeatures);

                    // Refresh the text roadmap
                    this._refreshRoadMap();

                    // Send the Lizmap event with the current route geometry
                    this._sendRouteGeometryAsWKT();

                    // Set back the node position used for arrow drawing to 0
                    this._nodePosition = 0;

                    // Get POIs
                    this._POIFeatures = json?.poi?.features ?? [];
                } else {
                    lizMap.addMessage(this._locales['route.error'], 'error', true);
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
        lizMap.litHTML.render(this._mainTemplate(), this);
    }

    /**
     * Convert the current route linestring geometry into WKT
     * and trigger the Lizmap event lizmapPgroutingWktGeometryExported
     * with the generated WKT
     */
    _sendRouteGeometryAsWKT() {

        // Generate the OpenLayers geometry from the route parts
        this.generateFeatureGeometry();

        // Trigger a Lizmap event with the stored geometry exported as WKT
        // Useful to get used by LWC <= 3.7 by other JS codes
        if (this._routeGeometry !== null) {
            // convert the OpenLayers geometry to WKT
            var format = new lizMap.ol.format.WKT();
            var wktGeometry = format.writeGeometry(this._routeGeometry);

            // Send the Lizmap event
            lizMap.events.triggerEvent(
                'lizmapPgroutingWktGeometryExported',
                {'wkt': wktGeometry}
            );
        }

    }
}

window.customElements.define('lizmap-pgrouting', pgRouting);
