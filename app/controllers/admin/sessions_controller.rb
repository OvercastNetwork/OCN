module Admin
    class SessionsController < BaseController
        breadcrumb "Sessions"

        def self.general_permission
            ['session', 'admin', true]
        end

        skip_before_filter :authenticate_admin

        def index
            @sessions = Session.desc(:start)
            if @user = model_param(User, :user_id)
                @sessions = @sessions.user(@user)
            end
            if @before = params[:before] and @before = Chronic.parse(@before)
                @sessions = @sessions.lte(start: @before)
            end
            if @ip = params[:ip] and !@ip.blank?
                @sessions = @sessions.where(ip: @ip)
            end
            if @nickname = params[:nickname] and !@nickname.blank?
                @sessions = @sessions.where(nickname_lower: @nickname.downcase)
            end
            hint = if @user
                if @nickname
                    Session::INDEX_user_nickname_start
                elsif @ip
                    Session::INDEX_user_ip_start
                else
                    Session::INDEX_user_start
                end
            elsif @ip
                Session::INDEX_ip_start
            else
                Session::INDEX_start
            end

            @sessions = a_page_of(@sessions.hint(hint), per_page: 40).prefetch(:player)
        end

        helper do
            def format_time(t)
                t.strftime("%F %T")
            end
        end
    end
end
