class User
    module Servers
        extend ActiveSupport::Concern
        include Sessions

        included do
            # Whether or not to display the server the user is currently on
            field :display_server, type: Boolean, default: true
            # The default server to send the player when they connect to the network
            belongs_to :default_server, class_name: 'Server', inverse_of: nil

            attr_accessible :display_server, as: :user
            attr_accessible :default_server_id, as: :user

            attr_accessible :default_server_id
            api_property :default_server_id

            attr_cached :current_server do
                current_session && current_session.server
            end
        end

        def can_set_default_server?
            premium?
        end

        def default_server_route
            default_server && default_server.online && default_server.bungee_name
        end

        def display_server_to?(viewer = User.current)
            display_server? || viewer.has_permission?('misc', 'player', 'view_display_server', true)
        end

        def current_datacenter
            current_server && current_server.datacenter
        end
    end
end
