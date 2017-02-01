class Server
    module Whitelist
        extend ActiveSupport::Concern

        included do
            # State of the whitelist at server startup
            field :whitelist_enabled, type: Boolean, default: false

            # If set, the API will deny all logins with the given message
            field :kick_users, type: Boolean, default: false
            field :kick_message, type: String

            attr_cloneable :whitelist_enabled

            api_property :whitelist_enabled
        end # included do
    end # Whitelist
end
