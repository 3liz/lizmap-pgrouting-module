# Changelog

## Unreleased

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
