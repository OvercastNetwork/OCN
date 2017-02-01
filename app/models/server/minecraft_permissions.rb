class Server
    module MinecraftPermissions
        extend ActiveSupport::Concern

        PUBLIC_REALMS = [:untourney]

        included do
            field :realms, type: Array, default: -> { ['global'] }
            scope :realms, -> (s) { self.in(realms: s.to_a) }

            attr_cloneable :realms

            api_property :realms

            api_synthetic :participant_permissions do
                group_permissions(Group.participant_group)
            end

            api_synthetic :observer_permissions do
                group_permissions(Group.observer_group)
            end

            api_synthetic :mapmaker_permissions do
                group_permissions(Group.mapmaker_group)
            end
        end # included do

        def group_permissions(group)
            group.mc_permission_map(realms)
        end
    end # MinecraftPermissions
end
