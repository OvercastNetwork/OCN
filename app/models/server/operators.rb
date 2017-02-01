class Server
    module Operators
        extend ActiveSupport::Concern

        included do
            # Users that are automatically made operators on this server
            has_and_belongs_to_many :operators, class_name: 'User', inverse_of: nil

            attr_cloneable :operators

            api_synthetic :operators do
                operators.mash{|u| [u.uuid, u.username] }
            end
        end # included do
    end # Operators
end
