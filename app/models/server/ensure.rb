class Server
    module Ensure
        extend ActiveSupport::Concern
        include Lifecycle

        RUNNING = 'running'
        STOPPING = 'stopping'

        included do
            field :ensure
            field :status
            attr_accessible :ensure

            # Commands to be run in the server console
            field :server_commands, :type => Array, :default => [].freeze

            api_synthetic :running do
                self.ensure == Ensure::RUNNING
            end

            before_event :up_or_down do
                self.server_commands = []
                true
            end
        end

        def absent?
            self.status == "absent"
        end

        def ensure_color
            case self.ensure
                when RUNNING
                    "status-ok"
                when STOPPING
                    "status-offline"
                when "starting"
                    "status-warning"
                else
                    "status-error"
            end
        end
    end
end
