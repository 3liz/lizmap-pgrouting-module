<?php

class search {
    protected $request_list = array(
        'get_short_path' = 'SELECT * FROM pgrouting.create_roadmap(\'$1\', \'$2\', $3);'
    );

    protected function getSql($option)
    {
        if (isset($this->sql[$option])) {
            return $this->sql[$option];
        }

        return null;
    }

    public function query($sql, $filterParams, $profile = 'pgrouting')
    {
        $cnx = jDb::getConnection($profile);
        $resultset = $cnx->prepare($sql);

        $resultset->execute($filterParams);

        return $resultset;
    }
    
    public function getData($repository, $project, $layer, $filterParams, $option)
    {
        // Need to create profile pgrouting
        $profile = 'pgrouting';
        $this->repository = $repository;
        $this->project = $project;

        // Run query
        $sql = $this->getSql($option);
        if (!$sql) {
            return null;
        }

        return $this->query($sql, $filterParams, $profile);
    }
}
