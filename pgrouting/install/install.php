<?php
/**
 * @author    3Liz
 * @copyright 2021-2022 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class pgroutingModuleInstaller extends \Jelix\Installer\Module\Installer
{
    public function preinstall(Jelix\Installer\Module\API\PreInstallHelpers $helpers)
    {
        // Check if all extensions was install
        $helpers->database()->useDbProfile('pgrouting');
        $db = $helpers->database()->dbConnection();

        $sql = 'SELECT extname FROM pg_extension WHERE extname = \'postgis\' OR extname = \'pgrouting\';';
        $result = $db->prepare($sql);
        $result->execute();
        $data = $result->fetchall();
        if (!count($data) == 2) {
            jLog::log('Extension missing in database, pgrouting or postgis', 'error');

            throw new jException('pgrouting~db.query.ext.bad');
        }
    }

    public function install(Jelix\Installer\Module\API\InstallHelpers $helpers)
    {
        $helpers->database()->useDbProfile('pgrouting');
        $db = $helpers->database()->dbConnection();

        // Get SQL template file
        $sql_file = $this->path . 'install/sql/install.pgsql.sql';
        $sql = jFile::read($sql_file);

        // Replace 2154 by given SRID if defined
        $srid = $this->getParameter('srid');
        if (is_numeric($srid) && $srid != '2154') {
            $sql = str_replace('2154', $srid, $sql);
        }

        $db->exec($sql);
    }
}
