class Forem::ApplicationController < ApplicationController

    before_filter :calculate_online_users

    def calculate_online_users
        key = "cache:online_users"
        result = REDIS.get(key)

        if result == nil
            result = calculate_online_users_full
            REDIS.set(key, result)
            REDIS.expire(key, 1.minute)
        end

        @users = result
        @users_count = result.count(",") # hack
    end

    def calculate_online_users_full
        users = User.where(:last_page_load_at.gt => 10.minutes.ago)
        online_list = {}

        users.each do |u|
            group = u.active_groups.first

            if group.nil?
                max = (2**(0.size * 8 - 2) - 1) # max int
            else
                max = group.priority
            end

            online_list[max] ||= Hash.new

            online_list[max].merge!({u.username => u.html_color})
        end

        users = ""
        online_list.sort.each do |group|
            group.each_with_index do |members, i|
                next if i == 0
                members.each do |user|
                    users += (view_context.link_to user[0], user_path(user[0]), :style => "color: " + user[1]) + ", "
                end
            end
        end
        users
    end

    private

    def authenticate_forem_user
        unless forem_user
            session['user_return_to'] = request.fullpath
            flash.alert = 'Please sign in to continue.'
            redirect_to main_app.new_user_session_path
        end
    end

    def admin?
        current_user && (current_user.admin? || current_user.has_permission?('admin', true))
    end
    helper_method :admin?
end
