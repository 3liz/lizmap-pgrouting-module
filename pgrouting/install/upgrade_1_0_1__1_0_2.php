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

class pgroutingModuleUpgrader_1_0_1__1_0_2 extends jInstallerModule
{
    use PgRoutingDBInstallTrait;

    public $targetVersions = array(
        '1.0.2',
    );
    public $date = '2023-06-22';

    public function install()
    {
        if ($this->firstDbExec()) {
            $this->useDbProfile('pgrouting');
            $db = $this->dbConnection();
            $this->launchGrantIntoDb($db);
        }
    }
}
