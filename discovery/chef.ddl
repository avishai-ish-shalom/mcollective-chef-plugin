metadata    :name        => "chef",
             :description => "Chef server search based discovery for node identities",
             :author      => "Avishai Ish-Shalom <avishai@fewbytes.com>",
             :license     => "Apache V2",
             :version     => "0.1",
             :url         => "",
             :timeout     => 0
 
discovery do
    capabilities :identity
end