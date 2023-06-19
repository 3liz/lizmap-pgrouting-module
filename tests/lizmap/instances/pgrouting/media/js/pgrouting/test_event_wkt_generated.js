lizMap.events.on({
    lizmapPgroutingWktGeometryExported: function(event) {
        console.log(`Route geometry as WKT = ${event.wkt}`);
    }
});
