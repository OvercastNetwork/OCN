class StaffController < ApplicationController
    def index
        @groups = Group.staff.by_priority
    end
end
