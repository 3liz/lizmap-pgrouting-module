<?php
/**
 * Service to provide translation dictionary.
 *
 * @author    3Liz
 * @copyright 2021 3Liz
 *
 * @see       https://3liz.com
 *
 * @license   Mozilla Public License : http://www.mozilla.org/MPL/
 */
class translateCtrl extends jController
{
    /**
     * Get json containing all translation for the dictionary.
     *
     * @return json
     */
    public function index()
    {
        $resp = $this->getResponse('json');

        $lang = $this->param('lang');

        if (!$lang) {
            $lang = \jLocale::getCurrentLang() . '_' . \jLocale::getCurrentCountry();
        }

        $data = array();
        $path = \jApp::getModulePath('pgrouting') . '/locales/en_US/dictionary.UTF-8.properties';

        if (file_exists($path)) {
            $lines = file($path);
            foreach ($lines as $lineContent) {
                if (!empty($lineContent) and $lineContent != '\n') {
                    $exp = explode('=', trim($lineContent));
                    if (!empty($exp[0])) {
                        $data[$exp[0]] = \jLocale::get('pgrouting~dictionary.' . $exp[0], null, $lang);
                    }
                }
            }
        }

        $resp->data = json_encode($data);

        return $resp;
    }
}
