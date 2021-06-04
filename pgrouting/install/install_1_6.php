<?php
/**
 * @author    your name
 * @copyright 2011-2020 3liz
 *
 * @see      http://3liz.com
 *
 * @license    All rights reserved
 */
class pgroutingModuleInstaller extends jInstallerModule
{
    public function install()
    {
        // Copy CSS and JS assets
        $this->copyDirectoryContent('../www/css', jApp::wwwPath('assets/pgrouting/css'));
        $this->copyDirectoryContent('../www/js', jApp::wwwPath('assets/pgrouting/js'));

        // SQL
        if ($this->firstDbExec()) {
            $sqlPath = $this->path.'install/sql/install.pgsql.sql';
            $sqlTpl = jFile::read($sqlPath);
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
