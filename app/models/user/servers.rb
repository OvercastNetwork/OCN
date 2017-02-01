class User
    module Servers
        extend ActiveSupport::Concern
        include Sessions

        included do
            # Whether or not to display the server the user is currently on
            field :display_server, type: Boolean, default: true

            attr_accessible :display_server, as: :user

            attr_cached :current_server do
                current_session && current_session.server
            end
        end

        def display_server_to?(viewer = User.current)
            display_server? || viewer.has_permission?('misc', 'player', 'view_display_server', true)
        end

        def current_datacenter
            current_server && current_server.datacenter
        end
    end
end
