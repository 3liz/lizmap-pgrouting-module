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

    function install() {
        if ($this->firstDbExec()) {
            $sqlPath = $this->path . 'install/sql/install.pgsql.sql';
            $sqlTpl = jFile::read( $sqlPath );
            $tpl = new jTpl();
            $srid = $this->getParameter('srid');
            $tpl->assign('srid', $srid);
            $sql = $tpl->fetchFromString($sqlTpl, 'text');
            $this->useDbProfile('pgrouting');
            $db = $this->dbConnection();
            $db->exec($sql);
        }
    }
}
