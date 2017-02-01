class Server
    module Dynamics
        extend ActiveSupport::Concern

        included do
            # dynamics format
            #
            # {
            #     enabled : true,
            #     size : 32,
            #     order : 1,
            #     updated : Time.now
            # }
            #
            field :dynamics, :type => Hash, :default => {}.freeze

            attr_cloneable :dynamics
        end

        def dynamics?
            self.dynamics["enabled"]
        end

        def dynamics_order
            self.dynamics["order"]
        end

        def dynamics_status
            if self.dynamics? && self.dynamics_order
                "Order: #{self.dynamics_order}"
            end
        end
    end
end
