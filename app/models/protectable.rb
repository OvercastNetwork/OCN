# Something that is protected by permissions
# TODO: expand this
module Protectable
    extend ActiveSupport::Concern

    module ClassMethods
        # Name of the permission node for this class
        def permission_node
            name.underscore
        end

        def can_manage?(user)
            user.has_permission?(permission_node, 'manage', true)
        end
    end

    delegate :permission_node, :can_manage?, to: 'self.class'
end
