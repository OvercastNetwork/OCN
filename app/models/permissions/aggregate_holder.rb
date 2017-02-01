module Permissions
    # An object that holds permissions indirectly through a list of other Holders.
    # This module implements #permissions in terms of #permission_groups, but does
    # not implement #with_permission.
    module AggregateHolder
        extend ActiveSupport::Concern
        include Holder

        module ClassMethods
            # Return the list of Holders that are included in every instance of this class
            def permission_groups
                []
            end
        end

        # Return the list of Holders that define this object's permissions, in priority order.
        def permission_groups
            [*instance_permission_groups, *self.class.permission_groups]
        end

        def admin?
            instance_admin? || permission_groups.any?(&:admin?)
        end

        # Return the list of Holders that are specific to this instance.
        # Subclasses must implement this.
        def instance_permission_groups
            raise NotImplementedError
        end

        def instance_admin?
            false
        end

        def permissions
            permission_groups.reverse.reduce({}) do |tree, holder|
                tree.deep_merge!(holder.permissions)
            end
        end
    end # Agent
 end
