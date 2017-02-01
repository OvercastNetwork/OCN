module Objective
    class DestroyableDestroy < Base
        field :blocks_broken
        field :blocks_broken_percentage

        required = [:blocks_broken, :blocks_broken_percentage]

        attr_accessible *required
        api_property *required
        validates_presence_of *required

        def self.total_description
            "monuments destroyed"
        end

        def percentage
            [1, (blocks_broken_percentage * 100).floor].max
        end
    end
end
