<?php
/**
 * @author    3Liz
 * @copyright 2021 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class pgroutingModuleUpgrader extends jInstallerModule {

    function install() {
        // Copy CSS and JS assets
        $this->copyDirectoryContent('../www/css', jApp::wwwPath('assets/pgrouting/css'));
        $this->copyDirectoryContent('../www/js', jApp::wwwPath('assets/pgrouting/js'));
    }
}
