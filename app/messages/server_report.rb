module ServerReport
    extend ActiveSupport::Concern
    include DatadogReport

    included do
        field :server_id
    end

    def datadog_tags
        tags = super
        if server = Server.find(server_id)
            tags += [
                "datacenter:#{server.datacenter}",
                "family:#{server.family}",
                "network:#{server.network}",
                "role:#{server.role}",
            ]
        end
        tags
    end

    def datadog_options
        opts = super
        if server = Server.find(server_id)
            opts.merge!(host: server.box_id,
                        device: server.bungee_name)
        else
            opts.merge!(device: server_id)
        end
        opts
    end
end
