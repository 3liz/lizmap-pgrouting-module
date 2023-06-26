<?php
/**
 * @author    3Liz
 * @copyright 2021 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class pgroutingModuleInstaller extends jInstallerModule
{
    public function preInstall()
    {
        // Check if all extensions was install
        $this->useDbProfile('pgrouting');
        $db = $this->dbConnection();

        $sql = 'SELECT extname FROM pg_extension WHERE extname = \'postgis\' OR extname = \'pgrouting\';';
        $result = $db->prepare($sql);
        $result->execute();
        $data = $result->fetchall();
        if (!count($data) == 2) {
            jLog::log('Extension missing in database, pgrouting or postgis', 'error');

            throw new jException('pgrouting~db.query.ext.bad');
        }
    }

    public function install()
    {
        // Copy CSS and JS assets
        $this->copyDirectoryContent('../www/css', jApp::wwwPath('assets/pgrouting/css'));
        $this->copyDirectoryContent('../www/js/dist', jApp::wwwPath('assets/pgrouting/js'));

        // SQL
        if ($this->firstDbExec()) {
            $this->useDbProfile('pgrouting');
            $db = $this->dbConnection();

            // Get SQL template file
            $sql_file = $this->path . 'install/sql/install.pgsql.sql';
            $sql = jFile::read($sql_file);

            // Replace 2154 by given SRID if defined
            $srid = $this->getParameter('srid');
            if (is_numeric($srid) && $srid != '2154') {
                $sql = str_replace('2154', $srid, $sql);
            }

            $db->exec($sql);
            $group = $this->getParameter('postgresql_user_group');
            if ($group) {
                // Grant right to the given PostgreSQL group of users
                $sql_file = $this->path . 'install/sql/grant.pgsql.sql';
                $template = jFile::read($sql_file);
                $tpl = new jTpl();
                $tpl->assign('userGroup', $group);
                if (!empty($group)) {
                    $sql = $tpl->fetchFromString($template, $group);
                    // Try to grant access
                    try {
                        $db->exec($sql);
                    } catch (Exception $e) {
                        jLog::log('An error occured while grant access on the pgrouting schema to the given group: ' . $group, 'error');

                        throw new jException('pgrouting~db.query.grant.bad');
                    }
                }
            }
        }
    }
}
