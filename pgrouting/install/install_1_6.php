<?php
/**
* @package   lizmap
* @subpackage pgrouting
* @author    your name
* @copyright 2011-2020 3liz
* @link      http://3liz.com
* @license    All rights reserved
*/


class pgroutingModuleInstaller extends jInstallerModule {

    function preInstall(){
        // Check if all extensions was install
        $this->useDbProfile('pgrouting');
        $db = $this->dbConnection();

        $sql = 'SELECT extname FROM pg_extension WHERE extname = \'postgis\' OR extname = \'pgrouting\';';
        $result = $db->prepare($sql);
        $result->execute();
        $data = $result->fetchall();
        if (count($data) == 2) {
            throw new jException('pgrouting~db.query.ext.bad');
        }
    }

    function install() {
        // Copy CSS and JS assets
        $this->copyDirectoryContent('../www/css', jApp::wwwPath('assets/pgrouting/css'));
        $this->copyDirectoryContent('../www/js', jApp::wwwPath('assets/pgrouting/js'));

        // SQL
        if ($this->firstDbExec()) {

            $this->useDbProfile('pgrouting');
            $db = $this->dbConnection();

            $sqlPath = $this->path . 'install/sql/install.pgsql.sql';
            $sqlTpl = jFile::read( $sqlPath );
            $tpl = new jTpl();
            $srid = $this->getParameter('srid');
            $tpl->assign('srid', $srid);
            $sql = $tpl->fetchFromString($sqlTpl, 'text');
            
            $db->exec($sql);
        }
    }
}
