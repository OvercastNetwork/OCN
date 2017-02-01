module Admin
    class GroupsController < BaseController
        def self.general_permission
            ['group', 'parent', 'admin', true]
        end

        skip_before_filter :authenticate_admin

        def index
            @groups = Group.all.by_priority.select{|g| g.can_edit?(:members, current_user_safe) }
        end
    end
end
