<?php

/**
 * @author    3Liz
 * @copyright 2021 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class defaultCtrl extends jController
{
    public function index()
    {
        $resp = $this->getResponse('json');
        $filterParams = array();

        // check that the repository, project, geom, srid parameters are not null or empty

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

        // test of the X, Y values of the points
        $xy = explode(',', $origin);
        if (count($xy) != 2) {
            $resp->data = array(
                'status' => 'error',
                'message' => 'The origin point must be composed of only 2 values representing x and y',
            );

            return $resp;
        }
        for ($i = 0; $i < count($xy); ++$i) {
            if (!is_numeric($xy[$i])) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'The value of the origin point is not numeric',
                );

                return $resp;
            }
            $xy[$i] = floatval($xy[$i]);
        }

        if ($crs === 4326) {
            if ($xy[0] < -180 || $xy[0] > 180) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'The X value of the origin point must be between -180 and 180',
                );

                return $resp;
            }

            if ($xy[1] < -90 || $xy[1] > 90) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'The Y value of the origin point must be between -90 and 90',
                );

                return $resp;
            }
        }

        $xy_dest = explode(',', $destination);
        if (count($xy_dest) != 2) {
            $resp->data = array(
                'status' => 'error',
                'message' => 'The destination point must be composed of only 2 values representing x and y',
            );

            return $resp;
        }

        for ($i = 0; $i < count($xy_dest); ++$i) {
            if (!is_numeric($xy_dest[$i])) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'The value of the destination point is not numeric',
                );

                return $resp;
            }
            $xy_dest[$i] = floatval($xy_dest[$i]);
        }

        if ($crs === 4326) {
            if ($xy_dest[0] < -180 || $xy_dest[0] > 180) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'The X value of the destination point must be between -180 and 180',
                );

                return $resp;
            }

            if ($xy_dest[1] < -90 || $xy_dest[1] > 90) {
                $resp->data = array(
                    'status' => 'error',
                    'message' => 'The X value of the destination point must be between -90 and 90',
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
        $origin = str_replace(',', ' ', $origin);
        $destination = str_replace(',', ' ', $destination);

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

        if (!is_array($result['data'])) {
            jLog::log('Request routing result error format', 'warning');

            return array(
                'status' => 'error',
                'message' => 'Result request error format',
            );
        }
        $routing_result = $result['data'][0];
        $routing = $routing_result->routing;
        $poi = $routing_result->poi;
        $routing = json_decode($routing);
        $poi = json_decode($poi);

        $result = array(
            'status' => 'success',
            'routing' => $routing,
            'poi' => $poi,
        );
        $resp->data = $result;

        return $resp;
    }
}
