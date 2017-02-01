class User
    module Classes
        extend ActiveSupport::Concern
        
        included do
            field :classes, type: Hash, default: -> { {} }
            api_property :classes
        end # included do

        def change_class!(category, name)
            if name.nil?
                classes.delete(category.to_s)
            else
                classes[category.to_s] = name.to_s
            end
            save!
        end
    end # Classes
 end
