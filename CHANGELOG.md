# Changelog

## Unreleased

### Fixed

* Fix rights on pgrouting schema sequences to allow the user to set or reset
  the PostgreSQL sequences when re-importing edges and nodes

## 1.0.6 - 2023-06-30

### Changed

* Improve the style of the route and start, intermediate & end points

### Fixed

* Geometry saved to local storage & WKT exported - Export all the missing nodes.

## 1.0.5 - 2023-06-29

### Fixed

* Upgrade method - Overwrite the existing JavaScript and CSS files by the new versions
  when running the upgrade.

## 1.0.4 - 2023-06-27

### Changed

* QGIS Project - use a **project variable** `lizmap_pgrouting_enabled=yes` to activate the module.
  Before, the project file name must contain the word `pgrouting` so that the module was activated,
  which was not very practical.
* Docs - Improve the installation documentation.
* Docs - Adapt the SQL import example to the new field names of the BDTOPO road datasource.

## 1.0.3 - 2023-06-27

### Fixed

* Handle other map projections than `4326` and `3857`

## 1.0.2 - 2023-06-26

### Added

* Missing script to call during the upgrade, to set write access to a group on the pgrouting schema

## 1.0.1 - 2023-06-21

### Added

* Trigger a Lizmap event `lizmapPgroutingWktGeometryExported` containing the generated WKT
  to allow JavaScript scripts for LWC <= 3.6 to use the generated route geometry.

### Changed

* Installation - Grant the write access on the schema `pgrouting` and its content to the
  given group (use installation parameter `postgresql_user_group`)

## 1.0.0 - 2023-06-09

### Added

* Support for intermediate points when drawing
* Copy the geometry which has been computed, Lizmap Web Client 3.7 only. Useful for pasting geometry when editing
* Installable into the future Lizmap 3.7

### Fixed

- Fix the button "Reverse edges" to respect the routing direction
- Improve robustness

## 0.3.1 - 2022-12-15

### Fixed

* Improve compatibility with Lizmap 3.6

## 0.3.0 - 2022-10-13

### Added

* Experimental compatibility with Lizmap 3.6

### Fixed

* The module is now compatible with Lizmap 3.5.6

## 0.2.1 - 2021-10-19

* Drop the previous roadmap when no routes were found in the database and display a message

## 0.2.0 - 2021-10-15

* Add some checks for SQL query results
* Add a PHP class to check the configuration (database extension and structure, required QGIS project layers)
* Improve the import script example for French IGN BdTopo
* Improve the spatial query performance
* Add a default label 'unnamed road' in the pgRouting dock when the edge has no label
* Add a button to reset start and end point

## 0.1.0 - 2021-06-22

* First version of the module
