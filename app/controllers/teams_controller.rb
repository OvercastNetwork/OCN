class TeamsController < ApplicationController
    include ActionView::Helpers::DateHelper

    before_filter :block_in_game_banned_users, :except => [:show, :index]
    before_filter :valid_user, :except => [:show, :index]
    before_filter :find_team, :except => [:index, :new, :create]
    before_filter :find_tournament, :only => [:register, :submit_registration, :unregister, :confirm_participation]
    before_filter :assert_registration_open, :only => [:register, :submit_registration, :confirm_participation]

    def index
        @teams = Team.order_by([[:member_count, :desc], [:name, :asc]])
        @teams = a_page_of(@teams)
    end

    def show
        @leader = @team.can_edit?(current_user)

        if @leader
            @members = @team.members
        else
            @members = @team.accepted_members
        end

        @members.sort!

        @stats = {
            :kk => {:arr => [], :averageable => true},
            :kd => {:arr => [], :averageable => true},
            :kills => {:arr => [], :averageable => false},
            :deaths => {:arr => [], :averageable => false},
            :wools => {:arr => [], :averageable => false},
            :cores => {:arr => [], :averageable => false},
            :destroyables => {:arr => [], :averageable => false}
        }

        stats = PlayerStat::Eternal.where(:id.in => @team.accepted_members.map{|m| m.user.player_id })

        stats.to_a.each do |stat|
            @stats[:kk][:arr] << stat.pretty_stat(:kk)
            @stats[:kd][:arr] << stat.pretty_stat(:kd)
            @stats[:kills][:arr] << stat.pretty_stat(:kills)
            @stats[:deaths][:arr] << stat.pretty_stat(:deaths)
            @stats[:wools][:arr] << stat.pretty_stat(:wool_placed)
            @stats[:cores][:arr] << stat.pretty_stat(:cores_leaked)
            @stats[:destroyables][:arr] << stat.pretty_stat(:destroyables_destroyed)
        end

        @stats.each do |k,v|
            if v[:averageable] && v[:arr].length > 0
                @stats[k] = (v[:arr].inject(:+).to_f / v[:arr].length).round(3)
            else
                @stats[k] = v[:arr].inject(:+) || 0
            end
        end

        params[:page] ||= 1
        params[:page] = 1 if params[:page].to_i < 1 || params[:page].to_i > (@members.count.to_f / PGM::Application.config.global_per_page).ceil

        @members = Kaminari.paginate_array(@members).page(params[:page]).per(PGM::Application.config.global_per_page)
    end

    def new
        return redirect_to_back teams_path, :alert => 'You already have a team.' if current_user.has_team?

        @new_team = Team.new(leader: current_user)
    end

    def create
        return redirect_to_back teams_path, :alert => 'You already have a team.' if current_user.has_team?

        team = Team.new(name: params[:team][:name], leader: current_user)

        if team.save
            redirect_to team_path(team), :alert => 'Team successfully created.'
        else
            redirect_to_back teams_path, :alert => describe_error(team)
        end
    end

    def edit
        redirect_to_back team_path(@team), :alert => 'You do not have permission to edit this team.' unless @team.can_edit?(current_user)
    end

    def update
        return redirect_to_back team_path(@team), :alert => 'Your team is currently participating in a tournament and may not be modified.' if @team.participating_any? && !current_user.admin?
        return redirect_to_back edit_team_path(@team), :alert => 'You do not have permission to edit this team.' unless @team.can_edit?(current_user)
        return redirect_to_back edit_team_path(@team), :alert => 'No changes specified.' if params[:team][:name] == @team.name

        @team.name = params[:team][:name]
        if @team.save
            redirect_to team_path(@team), :alert => 'Team successfully updated.'
        else
            redirect_to_back edit_team_path(@team), :alert => describe_error(@team)
        end
    end

    def register
        return redirect_to_back teams_path, :alert => 'You do not have permission to participate in tournaments.' unless Tournament.can_participate?(current_user)
        return redirect_to_back team_path(@team), :alert => 'You do not have permission to register this team.' unless @team.can_edit?(current_user)
        return redirect_to_back team_path(@team), :alert => 'Your team is already registered for this tournament.' if @tournament.team_registered?(@team)

        @members = @team.accepted_members.sort
    end

    def submit_registration
        return redirect_to_back teams_path, :alert => 'You do not have permission to participate in tournaments.' unless Tournament.can_participate?(current_user)
        return redirect_to_back team_path(@team), :alert => 'You do not have permission to register this team.' unless @team.leader == current_user
        return redirect_to_back team_path(@team), :alert => 'Your team is already registered for this tournament.' if @tournament.team_registered?(@team)
        if params[:registration] && params[:registration][:members]
            return redirect_to_back team_path(@team), :alert => 'You have too many members to register for this tournament.' if params[:registration][:members].count + 1 > @tournament.max_players_per_team
            return redirect_to_back team_path(@team), :alert => "You don't have enough members to register for this tournament." if params[:registration][:members].count + 1 < @tournament.min_players_per_team
        elsif @tournament.min_players_per_team > 1
            return redirect_to_back team_path(@team), :alert => "You don't have enough members to register for this tournament."
        elsif @tournament.max_players_per_team < 1
            return redirect_to_back team_path(@team), :alert => 'You have too many members to register for this tournament.' if params[:registration][:members].count + 1 > @tournament.max_players_per_team
        end

        user_ids = (params[:registration] && params[:registration][:members]) ? params[:registration][:members].select{|k, v| v == '1'}.keys : %w()
        users = User.where(:id.in => user_ids).to_a
        return redirect_to_back team_path(@team), :alert => 'There was a problem accessing one of the players you selected.' unless user_ids.size == users.size
        return redirect_to_back team_path(@team), :alert => 'One or more of your selected members was unable to be found or has not confirmed their invitation.' unless users.all?{|u| @team.is_accepted_member?(u) }
        return redirect_to_back team_path(@team), :alert => 'One or more of your selected members does not have permission to participate in tournaments.' unless users.all?{|u| Tournament.can_participate?(u) }

        @tournament.register_team!(@team, users)

        redirect_to tournament_path(@tournament.url), :notice => 'You have successfully registered. Please advise your team members to confirm their participation. Once all team members have confirmed, your team will be submitted for acceptance.'
    end

    def unregister
        return redirect_to_back team_path(@team), :alert => 'You do not have permission to un-register this team.' unless @team.can_edit?(current_user)
        return redirect_to_back team_path(@team), :alert => "Your team's participation has been confirmed. Your team may no longer be un-registered." if !current_user.admin? && @tournament.team_confirmed?(@team)
        return redirect_to_back team_path(@team), :alert => 'This tournament has ended and may no longer be modified. This registration is now permanent.' if Time.now > @tournament.end

        @tournament.unregister_team!(@team)

        redirect_to tournament_path(@tournament.url), :alert => 'Team successfully un-registered.'
    end

    def confirm_participation
        return redirect_to_back team_path(@team), :alert => 'You are not a member of this team.' unless @team.is_member?(current_user)
        return redirect_to_back team_path(@team), :alert => 'Your team is not participating in this tournament.' unless entrant = @tournament.entrant_for(@team)
        return redirect_to_back team_path(@team), :alert => 'You have no pending participation for this tournament.' unless member = entrant.member_for(current_user) and !member.confirmed?

        if member.confirm!
            redirect_to tournament_path(@tournament.url), :alert => 'Participation successfully confirmed. Good luck!'
        else
            redirect_to tournament_path(@tournament.url), :alert => "There was a problem confirming your participation. Please report this to #{ORG::EMAIL}"
        end
    end

    def update_invitation
        decision = nil
        if params[:decision].nil?
            return redirect_to_back teams_path, :alert => 'No decision specified.'
        else
            begin
                decision = to_boolean(params[:decision])
            rescue
                return redirect_to_back teams_path, :alert => 'Invalid decision specified.'
            end
        end
        return redirect_to_back teams_path, :alert => 'You already have a team.' if decision && current_user.has_team?
        return redirect_to_back team_path(@team), :alert => 'You do not have an invitation to this team.' unless @team.is_invited?(current_user)

        @team.mark_invitation!(current_user, decision)

        redirect_to team_path(@team), :alert => "Invitation #{decision ? 'accepted' : 'declined'}."
    end

    def add_member
        return redirect_to_back team_path(@team), :alert => 'You do not have permission to edit this team.' unless @team.can_edit?(current_user)
        return redirect_to_back team_path(@team), :alert => 'User not found.' unless user = User.by_username(params[:user])
        return redirect_to_back team_path(@team), :alert => "#{user.username} is already a member of another team." if user.has_team?
        return redirect_to_back team_path(@team), :alert => "You have already invited #{user.username}" if @team.is_member?(user)

        if params[:submit] == 'Force Add'
            raise Forbidden unless Tournament.can_manage?
            @team.force_add!(user)
            redirect_to_back team_path(@team), :alert => "Added member #{user.username}."
        elsif params[:submit] == 'Invite'
            @team.invite!(user)
            redirect_to_back team_path(@team), :alert => "Invitation sent to #{user.username}."
        end
    end

    def remove_member
        return redirect_to_back teams_path, :alert => 'User not found.' unless user = User.find(params[:user])
        return redirect_to_back team_path(@team), :alert => 'User is not a member of this team.' unless @team.is_member?(user)
        return redirect_to_back team_path(@team), :alert => "#{user.username} is currently participating in a tournament and may not be removed." if @team.membership_locked?(user)
        return redirect_to_back team_path(@team), :alert => 'You do not have permission to edit this team.' unless @team.can_edit?(current_user) || user == current_user

        if current_user == user
            @team.leave!(user)
        else
            @team.eject!(user)
        end

        if @team.alive?
            redirect_to_back team_path(@team), :alert => 'User successfully removed.'
        else
            redirect_to teams_path, :alert => 'Team disbanded.'
        end
    end

    def reassign_leader
        return redirect_to_back teams_path, :alert => 'No user specified.' unless user = User.find(params[:user])
        return redirect_to_back team_path(@team), :alert => 'User not found.' unless @team.is_member?(user)
        return redirect_to_back team_path(@team), :alert => 'User has not accepted their invitation.' unless @team.is_accepted_member?(user)
        return redirect_to_back team_path(@team), :alert => 'You do not have permission to re-assign the leader.' unless current_user.admin?

        @team.change_leader!(user)
        redirect_to_back team_path(@team), :alert => 'Leader successfully changed.'
    end

    protected

    def find_team
        id = params[:team_id] || params[:id]
        return redirect_to_back teams_path, :alert => 'No team specified.' if id.to_s.blank?
        @team = Team.where(name_normalized: id).first
        @team ||= Team.where(id: id).first
        return redirect_to_back teams_path, :alert => 'Invalid team.' unless @team
    end

    def find_tournament
        @tournament = model_param(Tournament, :tournament)
    end

    def assert_registration_open
        return redirect_to_back team_path(@team), :alert => 'This tournament is not open for registration.' unless @tournament.can_register?
    end

    def describe_error(team)
        case team.name_error
            when :invalid
                "Team name may only contain latin letters, number, spaces, and the following symbols: _ ' , . ! ? @ # $ % & ( ) : + = -"
            when :taken
                "Team name is too similar to the name of an already existing team"
            when :short
                "Team name must contain at least two letters or numbers"
            when :long
                "Team name cannot be longer than 32 characters"
            else
                "Team failed to save. If the problem persists, please contact #{ORG::EMAIL}"
        end
    end
end
