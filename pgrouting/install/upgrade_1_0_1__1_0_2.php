<?php
/**
 * @author    3Liz
 * @copyright 2023 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class pgroutingModuleUpgrader_1_0_1__1_0_2 extends jInstallerModule
{
    public $targetVersions = array(
        '1.0.2',
    );
    public $date = '2023-06-22';

    public function install()
    {
        if ($this->firstDbExec()) {
            $this->useDbProfile('pgrouting');
            $db = $this->dbConnection();

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
