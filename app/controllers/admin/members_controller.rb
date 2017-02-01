module Admin
    class MembersController < BaseController
        class << self
            def general_permission
                ['group', 'parent', 'admin', true]
            end
        end

        skip_before_filter :authenticate_admin
        skip_before_filter :html_only, :only => [:create]

        before_filter :find_group
        before_filter :find_user, only: [:show, :update, :destroy]
        before_filter :find_membership, only: [:show, :update]
        before_filter :authenticate

        def index
            # It sucks that Kaminari can't paginate transformed results without
            # loading the entire thing into an array. Though even if it could,
            # we would still need the array to sort by start date, because Mongo
            # can't do that.
            @memberships = User.in_group(@group, at: nil).map do |user|
                user.memberships.find_by(group: @group)
            end

            @params = params

            sort_fields = %w(username start stop)
            sort_fields = [@params[:order], *sort_fields.except(@params[:order])] if sort_fields.member?(@params[:order])
            @memberships.sort_by!{|m| sort_fields.map{|f| m.send(f) } }

            @memberships = Kaminari.paginate_array(@memberships).page(params[:page] || 0)
        end

        def show
            breadcrumb @membership.user.username
        end

        def new
            @membership = Group::Membership.new(group: @group)
        end

        def create
            membership = params[:membership]
            user = User.by_username(membership[:user]) or return not_found
            user.join_group(@group, start: parse_start(membership[:start]), stop: parse_stop(membership[:stop]), staff_role: membership[:staff_role])
            flash[:alert] = user.username + " was added to the group"
            redirect_to [:admin, @group, :members]
        end

        def destroy
            if @user.in_group?(@group, false)
                @user.leave_group(@group)
                flash[:alert] = @user.username + " was removed from the group"
            end
            redirect_to [:admin, @group, :members]
        end

        def update
            membership = params[:membership]
            @membership.start = parse_start(membership[:start])
            @membership.stop = parse_stop(membership[:stop])
            @membership.staff_role = membership[:staff_role]
            @user.save!
            redirect_to [:admin, @group, :members]
        end

        protected

        def breadcrumb_prefix
            [
                *GroupsController.breadcrumb_trail,
                [@group.name, admin_group_members_path]
            ]
        end

        def find_user
            @user = player_param(:id)
        end

        def find_group
            @group = model_param(Group, :group_id)
        end

        def find_membership
            not_found unless @membership = @user.memberships.find_by(group: @group)
            @start_text = (@membership.start unless @membership.start == Time::INF_PAST).to_s
            @stop_text = (@membership.stop unless @membership.stop == Time::INF_FUTURE).to_s
        end

        def authenticate
            not_found unless @group.can_edit?('members', current_user)
        end

        def parse_start(text)
            if text.blank?
                Time.now
            else
                Chronic.parse(text)
            end
        end

        def parse_stop(text)
            if text.blank?
                Time::INF_FUTURE
            else
                Chronic.parse(text)
            end
        end
    end
end
