class BungeeMetric
    include Mongoid::Document
    store_in :database => "oc_bungee_metrics"

end
