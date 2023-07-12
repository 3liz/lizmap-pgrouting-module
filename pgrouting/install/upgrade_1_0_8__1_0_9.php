<?php
/**
 * @author    3Liz
 * @copyright 2023 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
require_once __DIR__ . '/PgRoutingDBInstallTrait.php';

class pgroutingModuleUpgrader_1_0_8__1_0_9 extends jInstallerModule
{
    use PgRoutingDBInstallTrait;

    public $targetVersions = array(
        '1.0.9',
    );
    public $date = '2023-07-11';

    public function install()
    {
        if ($this->firstDbExec()) {
            $this->useDbProfile('pgrouting');
            $db = $this->dbConnection();
            $db->exec("COMMENT ON TABLE pgrouting.nodes IS 'PgRouting graph nodes'; COMMENT ON TABLE pgrouting.nodes IS 'PgRouting graph edges, with costs';");
        }
    }
}
