class User
    module Trophies
        extend ActiveSupport::Concern

        included do
            has_and_belongs_to_many :trophies, inverse_of: nil, after_add: :send_trophy_alert

            api_property :trophy_ids
            attr_accessible :trophy_ids

            index(INDEX_trophy = {trophy_ids: 1})

            scope :with_trophy, -> (trophy) { where(trophy_ids: trophy.id).hint(INDEX_trophy) }
        end

        def send_trophy_alert(trophy)
            Trophy::Alert.create!(user: self, trophy: trophy)
        end

        def has_trophy?(trophy)
            trophy_ids.include?(trophy.id)
        end
    end
end
