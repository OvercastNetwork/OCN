case Rails.env
    when 'development', 'staging', 'production'
        Box.define do
            box Box.local_id do
                hostname Socket.gethostname
                workers [RepoWorker, 
                         CouchWorker,
                         (ServerReportWorker if Dog.client), ModelSearchWorker,
                         ChannelWorker, EngagementWorker,
                         #ChartWorker,
                         TaskWorker, MatchMaker].compact
                services [:octc]
            end
        end
end
