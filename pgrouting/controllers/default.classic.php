<?php

/**
 * @package   lizmap
 * @subpackage pgrouting
 * @author    your name
 * @copyright 2011-2020 3liz
 * @link      http://3liz.com
 * @license    All rights reserved
 */

class defaultCtrl extends jController
{
    /**
     *
     */
    function index()
    {
        $resp = $this->getResponse('json');
        $filterParams = array();

        // vérifier que les paramètres repository, project, geom, srid sont non null ou vide

        $project = $this->param('project');
        $repository = $this->param('repository');
        $origin = $this->param('origin');
        $destination = $this->param('destination');
        $crs = $this->param('crs');
        $option = $this->param('option');

        // Check parameters
        if (!$project) {
            $resp->data = array('status' => 'error', 'message' => 'Project not found');

            return $resp;
        }

        if (!$repository) {
            $resp->data = array('status' => 'error', 'message' => 'Repository not found');

            return $resp;
        }

        if (!$origin) {
            $resp->data = array('status' => 'error', 'message' => 'Origin not found');

            return $resp;
        }

        if (!$destination) {
            $resp->data = array('status' => 'error', 'message' => 'Destination not found');

            return $resp;
        }

        if (!$crs) {
            $crs = 4326;
        }

        // test des valeur X,Y des points
        $xy = explode(',', $origin);
        if (count($xy) != 2) {
            $resp->data = array(
                'status' => 'error',
                'message' => 'Le point d\'origine doit être composé que de 2 valeurs uniquements représentant x et y'
            );

            return $resp;
        }
        for ($i = 0; $i < count($xy); $i++) {
            if (!is_numeric($xy[$i])) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'La valeur du point d\'origine n\'est pas du numérique'
                );

                return $resp;
            }
            $xy[$i] = floatval($xy[$i]);
        }

        if ($crs === 4326) {
            if ($xy[0] < -180 || $xy[0] > 180) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'La valeur X du point d\'origine doit être comprise entre -180 et 180 '. $xy[0]
                );

                return $resp;
            }

            if ($xy[1] < -90  || $xy[1] > 90) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'La valeur Y du point d\'origine doit être comprise entre -90 et 90'
                );

                return $resp;
            }
        }

        $xy_dest = explode(',', $destination);
        if (count($xy_dest) != 2) {
            $resp->data = array(
                'status' => 'error',
                'message' => 'Le point de destination doit être composé que de 2 valeurs uniquements représentant x et y'
            );

            return $resp;
        }

        for ($i = 0; $i < count($xy_dest); $i++) {
            if (!is_numeric($xy_dest[$i])) {
                $resp->data = array('status' => 'error', 'message' => 'La valeur du point d\'arrivé n\'est pas du numérique');

                return $resp;
            }
            $xy_dest[$i] = floatval($xy_dest[$i]);
        }

        if ($crs === 4326) {
            if ($xy_dest[0] < -180 || $xy_dest[0] > 180) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'La valeur X du point de destination doit être comprise entre -180 et 180'
                );

                return $resp;
            }

            if ($xy_dest[1] < -90 || $xy_dest[1] > 90) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'La valeur Y du point de destination doit être comprise entre -90 et 90'
                );

                return $resp;
            }
        }

        if (!$option) {
            $resp->data = array('status' => 'error', 'message' => 'Option not found');

            return $resp;
        }

        // check project

        $p = lizmap::getProject($repository . '~' . $project);
        if (!$p) {
            $resp->data = array('status' => 'error', 'message' => 'A problem occured while loading project with Lizmap');

            return $resp;
        }

        if (!$p->checkAcl()) {
            $resp->data = array('status' => 'error', 'message' => jLocale::get('view~default.repository.access.denied'));

            return $resp;
        }

        // Check layers

        $l = $p->findLayerByName('edges');
        if (!$l) {
            $resp->data = array('status' => 'error', 'message' => 'Layer ' . $l->name . ' does not exist');

            return $resp;
        }

        $layer = $p->getLayer($l->id);

        // Check if layer is a PostgreSQL layer
        if (!($layer->getProvider() == 'postgres')) {
            $resp->data = array('status' => 'error', 'message' => 'Layer ' . $layername . ' is not a PostgreSQL layer');

            return $resp;
        }

        $l = $p->findLayerByName('nodes');
        if (!$l) {
            $resp->data = array('status' => 'error', 'message' => 'Layer ' . $l->name . ' does not exist');

            return $resp;
        }

        $layer = $p->getLayer($l->id);

        // Check if layer is a PostgreSQL layer
        if (!($layer->getProvider() == 'postgres')) {
            $resp->data = array('status' => 'error', 'message' => 'Layer ' . $layername . ' is not a PostgreSQL layer');

            return $resp;
        }

        $profile = $layer->getDatasourceProfile();

        $origin = 'POINT(' . $origin . ')';
        $destination = 'POINT(' . $destination . ')';
        $origin = str_replace(",", " ", $origin);
        $destination = str_replace(",", " ", $destination);

        $filterParams[] = $origin;
        $filterParams[] = $destination;
        $filterParams[] = $crs;
        $filterParams[] = 'dijkstra';

        $search = jClasses::getService('pgrouting~search');

        $result = $search->getData($option, $filterParams, $profile);

        if ($result['status'] == 'error') {
            $resp->data = $result;

            return $resp;
        }

        $resp->data = $result['data'];
        return $resp;
    }
}
