class Server
    module Amqp
        extend ActiveSupport::Concern
        include ApiSyncable

        def routing_key
            "server.#{id}"
        end
    end # Amqp
end
