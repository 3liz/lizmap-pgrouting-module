<?php
/**
 * @author    3Liz
 * @copyright 2022 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
use Jelix\Routing\UrlMapping\EntryPointUrlModifier;
use \Jelix\Routing\UrlMapping\MapEntry\MapInclude;

class pgroutingModuleConfigurator extends \Jelix\Installer\Module\Configurator {

    public function getDefaultParameters()
    {
        return array(
            'srid' => 2154
        );
    }

    function configure(\Jelix\Installer\Module\API\ConfigurationHelpers $helpers)
    {
        $this->parameters['srid'] = $helpers->cli()->askInformation(
            'SRID your are using?', $this->parameters['srid']
        );

        $profileSearchPathChanged = false;
        list($profile, $realProfileName) = $helpers->findDbProfile('pgrouting');
        if (!$profile) {
            list($profile, $realDefaultProfileName) = $helpers->findDbProfile('default');
            if (!isset($profile['driver']) || $profile['driver'] != 'pgsql') {
                $profile = array(
                    'driver'=>  'pgsql',
                    'host' => 'localhost',
                    'port' => 5432,
                    'database' => 'lizmap',
                    'user' => 'lizmap',
                    'password' => "",
                    'search_path' => 'pgrouting,public'
                );
                $realProfileName = 'pgrouting';
            }
            else {
                $realProfileName = $realDefaultProfileName;
            }
        }

        if (!isset($profile['search_path'])) {
            $profile['search_path'] = 'pgrouting,public';
            $profileSearchPathChanged = true;
        }
        else if (strpos($profile['search_path'], 'pgrouting') === false) {
            $profile['search_path'] = 'pgrouting,'.$profile['search_path'];
            $profileSearchPathChanged = true;
        }

        $newProfile = $helpers->cli()->askDbProfile($profile);
        if ($newProfile != $profile) {
            // if the user change some parameters, we create a new profile or
            // change the existing pgrouting profile
            $helpers->declareDbProfile('pgrouting', $profile, true);
        } else if ($profileSearchPathChanged) {
            // no change, except the search path we modified
            $helpers->declareDbProfile($realProfileName, $profile, true);
        }

        $helpers->copyDirectoryContent('../www/css', jApp::wwwPath('assets/pgrouting/css'));
        $helpers->copyDirectoryContent('../www/js', jApp::wwwPath('assets/pgrouting/js'));
    }
}