class Server
    module Virtualization
        extend ActiveSupport::Concern

        included do
            field :pool, type: String
            field :server_definition, type: BSON::ObjectId
            field :virtual_hosts, type: Array, default: [].freeze

            scope :available_in_pool, -> (pool) { online.where(pool: pool).exists(server_definition: false) }
        end

        def pool_server
            Server.find_by(:server_definition => self._id)
        end
    end # Virtualization
end
