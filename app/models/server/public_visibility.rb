class Server
    class Visibility < Enum
        create :PUBLIC, :PRIVATE, :UNLISTED
    end

    module PublicVisibility
        extend ActiveSupport::Concern

        included do
            field :startup_visibility, type: Visibility, default: Visibility::UNLISTED
            field :visibility, type: Visibility, default: Visibility::UNLISTED
            attr_accessible :visibility

            validates_inclusion_of :visibility, in: Visibility.values

            scope :searchable, self.in(visibility: [ Visibility::PUBLIC, Visibility::UNLISTED ])
            scope :visible_to_public, where(visibility: Visibility::PUBLIC)

            attr_cloneable :startup_visibility

            api_property :visibility, :startup_visibility

            before_event :up_or_down do
                self.visibility = self.startup_visibility
                true
            end
        end # included do

        def visible_to_public?
            self.visibility == Visibility::PUBLIC
        end
    end # PublicVisibility
end
