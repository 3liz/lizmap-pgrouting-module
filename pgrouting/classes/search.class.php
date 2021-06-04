<?php

class search
{
    protected $sql = array(
        'get_short_path' => 'SELECT * FROM pgrouting.get_geojson_roadmap($1, $2, $3, $4);',
    );

    protected function getSql($option)
    {
        if (isset($this->sql[$option])) {
            return $this->sql[$option];
        }

        return null;
    }

    public function query($sql, $filterParams, $profile)
    {
        if ($profile) {
            $cnx = jDb::getConnection($profile);
        } else {
            // Default connection
            $cnx = jDb::getConnection();
        }

        $resultset = $cnx->prepare($sql);
        if (empty($filterParams)) {
            $resultset->execute();
        } else {
            $resultset->execute($filterParams);
        }

        return $resultset;
    }

    /**
     * Get data from the SQL query.
     *
     * @param mixed $profile
     * @param mixed $filterParams
     * @param mixed $option
     */
    public function getData($option = 'get_short_path', $filterParams = array(), $profile = null)
    {
        // Run query
        $sql = $this->getSql($option);
        if (!$sql) {
            return array(
                'status' => 'error',
                'message' => 'No SQL found for '.$option,
            );
        }

        try {
            $result = $this->query($sql, $filterParams, $profile);
        } catch (Exception $e) {
            return array(
                'status' => 'error',
                'message' => $e->getMessage(),
            );
        }

        if (!$result) {
            return array(
                'status' => 'error',
                'message' => 'Error at the query concerning '.$option,
            );
        }

        // Marche pour la requete de récupération du geojson
        // Il faudra surement modifier si d'autres requêtes
        $data = $result->fetchAll();
        $routing = $data[0]->routing;
        $poi = $data[0]->poi;
        $routing = json_decode($routing);
        $poi = json_decode($poi);

        return array(
            'status' => 'success',
            'data' => array(
                'routing' => $routing,
                'poi' => $poi,
            ),
        );
    }
}
