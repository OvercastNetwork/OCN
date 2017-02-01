require 'test_helper'

class TournamentTest < ActiveSupport::TestCase

    def assert_registered(tourney = @tourney, team = @team)
        assert tourney.team_registered?(team)
        assert_member tourney.registered_teams, team
        assert tourney.entrant_for(team)
        assert_member tourney.entrants, tourney.entrant_for(team)
    end

    def assert_confirmed(tourney = @tourney, team = @team)
        assert_registered(tourney, team)
        assert tourney.team_confirmed?(team)
        assert_member tourney.confirmed_teams, team
        assert tourney.entrant_for(team).confirmed?
    end

    def assert_accepted(tourney = @tourney, team = @team)
        assert_confirmed(tourney, team)
        assert tourney.team_accepted?(team)
        assert_member tourney.accepted_teams, team
        assert tourney.entrant_for(team).accepted?
    end

    def refute_accepted(tourney = @tourney, team = @team)
        refute tourney.team_accepted?(team)
        refute_member tourney.accepted_teams, team
        if entrant = tourney.entrant_for(team)
            refute entrant.accepted?
        end
    end

    def refute_confirmed(tourney = @tourney, team = @team)
        refute_accepted(tourney, team)
        refute tourney.team_confirmed?(team)
        refute_member tourney.confirmed_teams, team
        if entrant = tourney.entrant_for(team)
            refute entrant.confirmed?
        end
    end

    def refute_registered(tourney = @tourney, team = @team)
        refute_confirmed(tourney, team)
        refute tourney.team_registered?(team)
        refute_member tourney.registered_teams, team
        assert_nil tourney.entrant_for(team)
    end

    def register_team
        @user = create(:team_member)
        @team = @user.team
        @tourney = create(:tournament)
        @tourney.register_team!(@team, [@user])
        @entrant = @tourney.entrant_for(@team)
        @member = @entrant.member_for(@user)
    end

    test "register team" do
        register_team

        assert_registered
        refute_confirmed

        assert_set [@team.leader, @user], @entrant.users
        assert_set [@team.leader], @entrant.confirmed_users
        refute @entrant.user_confirmed?(@user)
        assert @entrant.user_unconfirmed?(@user)

        refute @member.confirmed?
    end

    test "confirm team" do
        register_team
        @member.confirm!

        assert_confirmed
        refute_accepted

        assert_set [@team.leader, @user], @entrant.confirmed_users
        assert @entrant.user_confirmed?(@user)
        refute @entrant.user_unconfirmed?(@user)

        assert @member.confirmed?
    end

    test "accept team" do
        register_team
        @member.confirm!
        @tourney.accept_team!(@team)

        assert_accepted
    end

    test "eject team" do
        register_team
        @member.confirm!
        @tourney.accept_team!(@team)
        @tourney.decline_team!(@team)

        assert_confirmed
        refute_accepted
    end

    test "unregister team" do
        register_team
        @tourney.unregister_team!(@team)

        refute_registered
    end
end
