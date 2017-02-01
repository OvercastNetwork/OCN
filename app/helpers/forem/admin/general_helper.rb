module Forem
    module Admin
        module GeneralHelper
            def forum_dropdown
                result = []

                Forem::Category.by_order.all.each do |category|
                    cat = []

                    Forem::Forum.by_order.where(:category_id => category.id).each do |forum|
                        cat << ["  " + forum.title, forum.id]
                    end

                    result << [category.name, cat]
                end

                result
            end
        end
    end
end
