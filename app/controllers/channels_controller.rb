class ChannelsController < ApplicationController
    def index
        @sort = choice_param(:sort, %w(subscribers videos views ))

        if group = Group.find_by(badge_type: 'youtube')
            @users = User.in_group(group)
            @channels = a_page_of(Channel::Youtube.in(user_ids: @users.map(&:id)).desc(@sort))
        end
    end
end
