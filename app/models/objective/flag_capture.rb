module Objective
    class FlagCapture < Base
        include Colored

        field :net_id

        attr_accessible :net_id
        api_property :net_id

        def self.total_description
            "flags captured"
        end
    end
end
