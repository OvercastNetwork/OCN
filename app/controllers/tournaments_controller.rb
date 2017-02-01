class TournamentsController < ApplicationController

    before_filter :find_tournament, except: [:index]
    before_filter :find_user, only: [:add_user, :remove_user, :confirm_user, :unconfirm_user]
    before_filter :find_team, except: [:index, :show]
    before_filter :valid_user, only: [:accept_team]

    def index
        @active_tournaments, @inactive_tournaments = Tournament.all.desc(:created_at).partition(&:active?)
    end

    def show
        return redirect_to_back tournaments_path, :alert => 'No tournament specified.' if params[:id].to_s.blank?


        unless @tournament.hide_teams
            @entrants = if @tournament.can_register? || Tournament.can_accept?(current_user_safe)
                @tournament.entrants
            else
                @tournament.accepted_entrants
            end.sort_by(&:registered_at)
            @teams = @entrants.map(&:team)

            if user_signed_in?
                @team = current_user.team
                unless @team.nil? || !@teams.include?(@team)
                    @participation_pending = @tournament.can_register? && @tournament.entrant_for(@team).user_unconfirmed?(current_user)
                end

                @has_actions = Tournament.can_manage? || Tournament.can_accept?(current_user) || Tournament.can_decline?(current_user)
            end

            @team_info = {
                :registered => @team && @tournament.team_registered?(@team),
                :participation_confirmed => @team && @tournament.team_confirmed?(@team)
            }
        end
    end

    def show_team
        raise Forbidden unless Tournament.can_manage?
    end

    def accept_team
        return redirect_to_back tournaments_path, :alert => 'You do not have permission to accept registrations.' unless Tournament.can_accept?(current_user)
        return redirect_to_back tournament_path(tournament.url), :alert => 'This registration is not eligible for acceptance.' unless @tournament.team_confirmed?(@team)

        @tournament.accept_team!(@team)
        redirect_to tournament_path(@tournament.url), :alert => 'Registration successfully accepted.'
    end

    def decline_team
        return redirect_to_back tournaments_path, :alert => 'You do not have permission to decline registrations.' unless Tournament.can_decline?(current_user)
        return redirect_to_back tournament_path(@tournament.url), :alert => 'This registration has not been accepted.' unless @tournament.team_accepted?(@team)

        @tournament.decline_team!(@team)
        redirect_to tournament_path(@tournament.url), :alert => 'Registration successfully declined.'
    end

    def add_user
        raise Forbidden unless Tournament.can_manage?
        unless @entrant.members.any?{|m| m.user == @user }
            @entrant.members << Tournament::Entrant::Member.new(user: @user)
            @team.save!
        end
        redirect_to tournament_show_team_path(@tournament.url, team_id: @team.id), alert: "Added #{@user.username}"
    end

    def remove_user
        raise Forbidden unless Tournament.can_manage?
        if member = @entrant.members.find_by(user: @user)
            @entrant.members.delete(member)
            @team.save!
        end
        redirect_to tournament_show_team_path(@tournament.url, team_id: @team.id), alert: "Removed #{@user.username}"
    end

    def confirm_user
        raise Forbidden unless Tournament.can_manage?
        if member = @entrant.members.find_by(user: @user)
            member.confirmed = true
            @team.save!
        end
        redirect_to tournament_show_team_path(@tournament.url, team_id: @team.id), alert: "Confirmed #{@user.username}"
    end

    def unconfirm_user
        raise Forbidden unless Tournament.can_manage?
        if member = @entrant.members.find_by(user: @user)
            member.confirmed = false
            @team.save!
        end
        redirect_to tournament_show_team_path(@tournament.url, team_id: @team.id), alert: "Unconfirmed #{@user.username}"
    end

    protected

    def find_tournament
        not_found unless @tournament = Tournament.find_by(url: params[:tournament_id] || params[:id])
    end

    def find_user
        not_found unless @user = User.find(params[:user_id])
    end

    def find_team
        @team = if @user
            @user.team
        else
            Team.find(params[:team_id])
        end
        return not_found unless @team
        return not_found unless @entrant = @tournament.entrant_for(@team)
    end
end
