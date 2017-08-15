class ApplicationController < CommonController
    include ApplicationHelper
    include UserHelper
    include ParamsHelper
    include PaginationHelper

    # CSRF protection - very important, do not remove this
    #
    # We use the default null_session behavior so that requests
    # that authenticate with an API key still work. Forged requests
    # will have no session, making them harmless. But requests that
    # authenticate by key don't need a session, so they still work.
    protect_from_forgery

    before_filter :check_general_permission
    before_filter :build_navigation
    before_filter :html_only, :except => [:autocomplete, :user_search, :model_search]
    before_render :find_alerts
    before_render :find_streams
    before_render :user_time_zone
    before_render :user_activity
    before_render :set_return_to


    # Raise from controller actions to redirect the user to the
    # previous page with an error message
    class Back < Exception
        attr_reader :path, :alert
        def initialize(path: nil, alert: nil)
            @path = path
            @alert = alert
        end
    end

    rescue_from Back do |ex|
        unless alert = ex.alert
            alert = "A strange error occurred - please report this to #{ORG::EMAIL}"
            Rails.logger.error "Controller action failed with no error message:\n#{ex.backtrace.join("\n")}"
        end
        redirect_to_back(ex.path, alert: alert)
    end

    def go_back(path: nil, alert: nil)
        raise Back.new(path: path, alert: alert)
    end

    def index
        images = Array.new
        (1..21).each{|i| images << "index/marketing/" + i.to_s + ".jpg"}
        @image = images.sample

        @topics = Forem::Topic.announcements.limit(4)
    end

    # Returns the permission required to access any part of this controller.
    # The base method returns the universal permission, which all users
    # should have (even the anonymous user). Subclasses can override the
    # method to implement more strict permissions.
    #
    # The permission is enforced by a filter in the base controller, and is
    # also used to generate the site dropdown menu.
    def self.general_permission
        Permissions.everybody_permission
    end

    def check_general_permission
        not_found unless current_user_safe.has_permission?(*self.class.general_permission)
    end

    def build_navigation
        if user_signed_in?
            @admin_nav = [
                { name: "Charts",        controller: Admin::ChartsController },
                { name: "Transactions",  controller: Admin::TransactionsController },
                { name: "Groups",        controller: Admin::GroupsController },
                { name: "Users",         controller: Admin::UsersController },
                { name: "Sessions",      controller: Admin::SessionsController },
                { name: "Categories",    controller: Admin::CategoriesController },
                { name: "Forums",        controller: Admin::ForumsController },
                { name: "Trophies",      controller: Admin::TrophiesController },
                { name: "Tournaments",   controller: Admin::TournamentsController },
                { name: "Streams",       controller: Admin::StreamsController },
                { name: "Banners",       controller: Admin::BannersController },
                { name: "Servers",       controller: Admin::ServersController },
                { name: "IP Bans",       controller: Admin::IpbansController },
            ]

            @nav = [
                { name: "Admin",         path: main_app.admin_root_path, sub: @admin_nav },
                { name: "Profile",       path: user_path(current_user.username) },
                { name: "Alerts",        path: main_app.alerts_path },
                { name: "Friendships",   path: main_app.friendships_path },
                { name: "Transactions",  path: main_app.transactions_path },
                { name: "Reports",       path: main_app.reports_path },
                { name: "Appeals",       path: main_app.appeals_path },
                { name: "Account",       path: main_app.edit_user_registration_path },
            ]
        end
    end

    def nav_controller(item)
        item[:controller] || self.class
    end

    def nav_action(item)
        item[:action] || 'index'
    end

    def nav_permission(item)
        item[:permission] || nav_controller(item).general_permission
    end

    def nav_path(item)
        item[:path] || main_app.routes.url_helpers.url_for(
            only_path: true,
            controller: nav_controller(item).controller_path,
            action: nav_action(item)
        )
    end

    def nav_link(item)
        %{<a href="#{nav_path(item)}">#{item[:name]}</a>}.html_safe
    end

    def can_navigate_to?(item, user = nil)
        (user || current_user_safe).has_permission?(nav_permission(item))
    end

    def render_navigation(item)
        if can_navigate_to?(item)
            if item[:sub]
                subs = item[:sub].map{|sub| render_navigation(sub) }.compact
                unless subs.empty?
                    %{
                        <li class="hidden-xs dropdown-submenu dropdown-submenu-left">
                            <a href="#" tabindex="-1">#{item[:name]}</a>
                            <ul class="dropdown-menu">
                                #{subs.join}
                            </ul>
                        </li>
                        <li class="visible-xs">#{nav_link(item)}</li>
                    }.html_safe
                end
            else
                %{<li>#{nav_link(item)}</li>}.html_safe
            end
        end
    end

    helper_method :nav_path, :nav_link, :can_navigate_to?, :render_navigation

    def donate
        return redirect_to shop_path
    end

    def live
        @streams = Stream.by_priority.where(:public => true)
        @tournament = Tournament.active.asc(:created_at).first
        @subtitle = @streams.first.status_text if @streams.first
    end

    def inquire
        params.permit(inquiry: [:username, :email, :subject, :message])
        params.require(:inquiry)

        inquiry = params[:inquiry]
        type = params[:type].to_s

        if !type.blank? && !inquiry.any? {|k, v| v.blank?}
            if UserMailer.inquiry_notification(inquiry["username"], inquiry["email"], inquiry["subject"], type, inquiry["message"]).deliver
                redirect_to_back root_path, :notice => "Thank You! Your inquiry was delivered succesfully."
            else
                redirect_to_back root_path, :alert => "Inquiry failed to deliver."
            end
        else
            redirect_to_back root_path, :alert => "Please fill out all the fields"
        end
    end

    def autocomplete
        query = mc_sanitize(params[:name].downcase)
        @matches = User.where(:username_lower => /^#{query}/).limit(5)
        render :json => @matches.map{|user| user.username}
    end

    def user_search
        query = mc_sanitize(params[:username].to_s.downcase)
        @matches = User.where(:username_lower => /^#{query}/).order_by(username_lower: 1).limit(5)
        render :json => {results: @matches.map{|user| {id: user.id.to_s, text: user.username} } } # This format is used by Select2
    end

    def model_search
        if user_signed_in?
            query, search_class, search_field = params[:request].split(',', 3)
            @matches = search_class.constantize
                                   .where(search_field => /^#{query}/i)
                                   .order_by(search_field => 1)
                                   .limit(5)
                                   .to_a
                                   .map(&:api_document)
            render :json => {results: @matches.map{|model| {id: model.id.to_s, text: model[search_field]} } }
        end
    end

    def load_models
        begin
            Repository[:data].load_models
        rescue Exception
            Rails.logger.error "An error occured while loading data models"
        end
        return render :nothing => true, :status => 200
    end

    def set_time_zone
        if user_signed_in?
            begin
                current_user.time_zone_name = TZInfo::Timezone.new(params[:time_zone_name]).name
            rescue Exception
            else
                current_user.save
            end
        end

        return render :nothing => true, :status => 200
    end

    def forem_user
        current_user
    end

    def peek_enabled?
        respond_to?(:current_user) && current_user && (current_user.admin? || current_user.has_permission?('misc', 'peek', 'view', true))
    end

    def html_only
        return if params[:controller] == "peek/results"
        not_found if request.format != Mime::ALL && request.format != Mime::HTML
    end

    protected

    def valid_user
        redirect_to new_user_session_path, :alert => 'You must be signed in to do this.' unless user_signed_in?
    end

    private
    def find_alerts
        if user_signed_in?
            # Read up to 26 alerts lazily. Some users have too many unread alerts to load in memory.
            q = current_user_safe.alerts.unread.desc(:updated_at).hint(Alert::INDEX_user_read)
            @alerts = q.lazy.select(&:valid?).take(26).to_a

            if @alerts.size <= 25
                # If there are <= 25 valid alerts, get the count from the array.
                # This way, the count is always accurate when the list doesn't overflow.
                @alert_count = @alerts.size
            else
                # If there are > 25 alerts, get the count from the query.
                # This may be inaccurate, since it includes invalid alerts,
                # but the user can't see all alerts, so hopefully they won't notice.
                @alerts = @alerts.take(25)
                @alert_count = q.count
            end
        end
    end

    def find_streams
        @nav_live = Stream.where(:public => true).exists?
    end

    def user_time_zone
        begin
            @timezone = (user_signed_in? ? TZInfo::Timezone.get(current_user.time_zone_name) : nil)
        rescue Exception
            @timezone = nil
        end
    end

    def user_activity
        if current_user != nil
            current_user.last_page_load_at = Time.now
            current_user.last_page_load_ip = request.remote_ip
            current_user.save

            current_user.add_to_set(web_ips: request.remote_ip)
        end
    end

    # Set the return path for redirecting actions. Because this is
    # a before_render callback, it is not called when redirecting,
    # and so it should always contain safe path to redirect to.
    def set_return_to
        unless is_a? Peek::ResultsController
            session[:return_to] = request.fullpath
        end
    end

    # Parse the page parameter, handle bad input
    def current_page
        int_param(:page) || 1
    end

    def last_page
        (@topic.posts.count.to_f / Forem.per_page.to_f).ceil
    end

    helper_method :forem_user, :find_notifications, :last_page, :current_user_safe
end
