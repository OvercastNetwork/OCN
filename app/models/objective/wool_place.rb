module Objective
    class WoolPlace < Base
        include Colored

        def self.total_description
            "wools placed"
        end

        def name
            if dye = dye_color
                "#{dye.name.titleize} Wool"
            end
        end
    end
end
