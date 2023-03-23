<?php
/**
 * @author    3Liz
 * @copyright 2021 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class pgroutingModuleUpgrader_0_3_1__1_0_0 extends jInstallerModule
{
    public $targetVersions = array(
        '1.0.0',
    );
    public $date = '2023-03-21';

    public function install()
    {
        if ($this->firstDbExec()) {
            $this->useDbProfile('pgrouting');
            $db = $this->dbConnection();

            // Get upgrade SQL template file
            $sql_file = $this->path . 'install/sql/upgrade/upgrade_0.3.1_1.0.0.sql';
            $sql = jFile::read($sql_file);

            // Replace 2154 by given SRID if defined
            $srid = $this->getParameter('srid');
            if (is_numeric($srid) && $srid != '2154') {
                $sql = str_replace('2154', $srid, $sql);
            }

            $db->exec($sql);
        }
    }
}
