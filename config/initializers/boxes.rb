case Rails.env
    when 'development'
        Box.define do
            box Box.local_id do
                hostname Socket.gethostname
                workers [RepoWorker, 
                         #CouchWorker, 
                         (ServerReportWorker if Dog.client), ModelSearchWorker,
                         ChannelWorker, EngagementWorker,
                         #ChartWorker, 
                         TaskWorker, MatchMaker].compact
                services [:octc]
            end
        end

    when 'staging'
        Box.define do
            datacenter 'DC' do
                box 'box01' do
                    services [:octc]
                end
            end
        end

    when 'production'
        Box.define do
            workers([RepoWorker]) do
                datacenter 'DC' do
                    box 'box01' do
                        workers [RepoWorker, TaskWorker, 
                                 #CouchWorker, 
                                 EngagementWorker, TranslationWorker]
                        services [:octc, :data]
                    end

                    box 'box02' do
                        workers [RepoWorker, TaskWorker, (ServerReportWorker if Dog.client), ModelSearchWorker, MatchMaker].compact
                        services [:octc]
                    end

                    box 'box03' do
                        workers [RepoWorker, TaskWorker, ChannelWorker,
                                 #ChartWorker
                                  ]
                        services [:octc]
                    end
                end
            end
        end
end
