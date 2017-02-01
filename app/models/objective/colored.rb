module Objective
    module Colored
        extend ActiveSupport::Concern

        included do
            field :color

            attr_accessible :color
            api_property :color
        end

        def dye_color
            DyeColor.parse(color.to_s.downcase.gsub(/_/, ' ')) if color
        end

        def html_color
            if dye = dye_color
                dye.to_html_color
            else
                super
            end
        end
    end
end
