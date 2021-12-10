<?php
/**
 * @author    3Liz
 * @copyright 2021 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class pgroutingModuleUpgrader_0_1_0__0_2_0 extends jInstallerModule
{
    public $targetVersions = array(
        '0.2.0',
    );
    public $date = '2021-10-12';

    public function install()
    {
        if ($this->firstDbExec()) {
            $this->useDbProfile('pgrouting');
            $db = $this->dbConnection();

            // Drop completely the schema as the first version was not optimized
            $sql = 'DROP SCHEMA IF EXISTS pgrouting CASCADE;';
            $db->exec($sql);

            // Reinstall from install SQL file
            // Get SQL template file
            $sql_file = $this->path . 'install/sql/install.pgsql.sql';
            $sqlTpl = jFile::read($sql_file);
            $tpl = new jTpl();
            $sql = $tpl->fetchFromString($sqlTpl, 'text');

            // Replace 2154 by given SRID if defined
            $srid = $this->getParameter('srid');
            if (is_int($srid) && $srid != '2154') {
                $sql = str_replace('2154', $srid, $sql);
            }

            $db->exec($sql);
        }
    }
}
