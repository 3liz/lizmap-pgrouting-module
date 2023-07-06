<?php
/**
 * @author    3Liz
 * @copyright 2023 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */

trait PgRoutingDBInstallTrait
{
    protected function launchGrantIntoDb(jDbConnection $db)
    {
        $group = $this->getParameter('postgresql_user_group');
        if ($group) {
            // Grant right to the given PostgreSQL group of users
            if (method_exists($this, 'getPath')) {
                $sql_file = $this->getPath()  . 'install/sql/grant.pgsql.sql';
            }
            else {
                $sql_file = $this->path . 'install/sql/grant.pgsql.sql';
            }
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