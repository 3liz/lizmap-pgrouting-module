<?php
/**
 * @author    3Liz
 * @copyright 2021 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class checkConfig
{
    protected $array_ext = array('pgrouting', 'postgis');

    protected $profile;

    protected $project;

    protected $repository;

    /**
     * @var search
     */
    protected $search;

    public function __construct($repository, $project, $profile)
    {
        $this->project = $project;
        $this->repository = $repository;
        $this->search = jClasses::getService('pgrouting~search');
        $this->profile = $profile;
    }

    public function checkDbExtension()
    {
        $resultBool = true;
        $message = '';
        $result = $this->search->getData('check_ext', array(), $this->profile);
        if ($result['status'] == 'error') {
            $resultBool = false;
            $message = 'PgRouting module error: '.$result['message'];
        }
        else if (count($result['data']) != 2) {
            $resultBool = false;
            $message = 'PgRouting module error: Extension missing in database (pgrouting or postgis)';
        }

        return array(
            'code' => $resultBool,
            'message' => $message,
        );
    }

    public function checkDbSchema()
    {
        $resultBool = true;
        $message = '';
        $result = $this->search->getData('check_schema', array(), $this->profile);
        if ($result['status'] == 'error') {
            $resultBool = false;
            $message = 'PgRouting module error: '.$result['message'];
        }
        else if(count($result['data']) != 1) {
            $resultBool = false;
            $message = 'PgRouting module error: Schema pgrouting missing in database';
        }

        return array(
            'code' => $resultBool,
            'message' => $message,
        );
    }

    public function allCheck()
    {
        $resultBool = true;
        $array_msg = array();
        $extCheck = $this->checkDbExtension();
        $schemaCheck = $this->checkDbSchema();
        $layerCheck = $this->checkProjectLayers();
        if ($extCheck['code'] == false) {
            $resultBool = false;
            array_push($array_msg, $extCheck['message']);
        }
        if ($schemaCheck['code'] == false) {
            $resultBool = false;
            array_push($array_msg, $schemaCheck['message']);
        }
        if ($layerCheck['code'] == false) {
            $resultBool = false;
            array_push($array_msg, $layerCheck['message']);
        }

        return array(
            'code' => $resultBool,
            'message' => $array_msg,
        );
    }

    public function checkProjectLayers()
    {
        $resultBool = true;
        $message = '';
        $p = lizmap::getProject($this->repository . '~' . $this->project);
        $edges = $p->findLayerByName('edges');
        $nodes = $p->findLayerByName('nodes');
        if (!$edges || !$nodes) {
            $resultBool = false;
            $message = 'PgRouting module error: Layer missing in project (edges or nodes)';
        }

        return array(
            'code' => $resultBool,
            'message' => $message,
        );
    }
}
