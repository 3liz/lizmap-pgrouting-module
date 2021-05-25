<?php
/**
* @package   lizmap
* @subpackage pgrouting
* @author    your name
* @copyright 2011-2020 3liz
* @link      http://3liz.com
* @license    All rights reserved
*/

class defaultCtrl extends jController {
    /**
    *
    */
    function index() {
        $rep = $this->getResponse('json');
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
            $rep->data = array('status' => 'error', 'message' => 'Project not found');

            return $rep;
        }
        if (!$repository) {
            $rep->data = array('status' => 'error', 'message' => 'Repository not found');

            return $rep;
        }
        if (!$origin) {
            $rep->data = array('status' => 'error', 'message' => 'Origin not found');

            return $rep;
        }
        if (!$destination) {
            $rep->data = array('status' => 'error', 'message' => 'Destination not found');

            return $rep;
        }
        if (!$crs) {
            $rep->data = array('status' => 'error', 'message' => 'SRID not found');

            return $rep;
        }
        if (!$option) {
            $rep->data = array('status' => 'error', 'message' => 'Option not found');

            return $rep;
        }

        // check project

        $p = lizmap::getProject($repository.'~'.$project);
        if (!$p) {
            $rep->data = array('status' => 'error', 'message' => 'A problem occured while loading project with Lizmap');

            return $rep;
        }

        if (!$p->checkAcl()) {
            $rep->data = array('status' => 'error', 'message' => jLocale::get('view~default.repository.access.denied'));

            return $rep;
        }

        // Check layers

        $l = $p->findLayerByName('edges');
        if (!$l) {
            $rep->data = array('status' => 'error', 'message' => 'Layer '.$l->name.' does not exist');

            return $rep;
        }

        $l = $p->findLayerByName('nodes');
        if (!$l) {
            $rep->data = array('status' => 'error', 'message' => 'Layer '.$l->name.' does not exist');

            return $rep;
        }

        $layer = $p->getLayer($l->id);

        // Check if layer is a PostgreSQL layer
        if (!($layer->getProvider() == 'postgres')) {
            $rep->data = array('status' => 'error', 'message' => 'Layer '.$layername.' is not a PostgreSQL layer');

            return $rep;
        }

        $profile = $layer->getDatasourceProfile();

        $origin = 'POINT('.$origin.')';
        $destination = 'POINT('.$destination.')';
        $origin = str_replace(",", " ", $origin);
        $destination = str_replace(",", " ", $destination);

        $filterParams[] = $origin;
        $filterParams[] = $destination;
        $filterParams[] = $crs;

        $search = jClasses::getService('pgrouting~search');

        $result = $search->getData($option, $filterParams, $profile);

        if ($result['status'] == 'error') {
            $rep->data = $result;

            return $rep;
        }

        $rep->data = $result['data'];
        return $rep;
    }
}

