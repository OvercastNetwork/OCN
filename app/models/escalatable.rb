module Escalatable
    extend ActiveSupport::Concern
    include Actionable
    include Subscribable

    included do
        field :escalated, type: Boolean, default: false

        scope :escalated, where(escalated: true)
        scope :not_escalated, ne(escalated: true)

        action Action::Escalate do
            self.escalated = true
            self.open = true if is_a? Closeable
            self.locked = false if is_a? Lockable
        end
    end

    module ClassMethods
        def can_handle_escalated?(user)
            can_manage?(user) || user.has_permission?(permission_node, 'alert', 'escalated', true)
        end
    end

    delegate :can_handle_escalated?, to: 'self.class'

    # Users who will be alerted/subscribed when this
    # object is escalated. The base methods returns
    # all admin users, plus users with manage or
    # escalate permissions.
    def escalation_users
        groups = Group.with_permission(permission_node, 'alert', 'escalated', true) | Group.with_permission(permission_node, 'manage', true)
        # We still need to test each user individually for the perm,
        # because a higher priority group could override it
        users = User.with_permission(permission_node, 'alert', 'escalated', true).to_a | User.with_permission(permission_node, 'manage', true).to_a
        users = users.select{|user| can_handle_escalated?(user) }
        [*users, *User.admins]
    end
end
