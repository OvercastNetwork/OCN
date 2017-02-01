module Objective
    class CoreBreak < Base
        field :material
        field :core_name # DEPRECATED

        attr_accessible :material, :core_name
        api_property :material
        validates_presence_of :material

        def self.total_description
            "cores leaked"
        end

        def name
            super || core_name || "Core"
        end
    end
end
