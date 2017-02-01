class Job
    include Mongoid::Document
    store_in :database => "oc_jobs"

    field :lastRun, :type => DateTime
    field :name
end
