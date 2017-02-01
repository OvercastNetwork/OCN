require 'test_helper'

class TeamsControllerTest < ActionController::TestCase
    setup do
        @user = create(:user)
        sign_in @user
    end

    test "team list" do
        create(:team, name: "A-Team")
        create(:team, name: "B-Team")
        create(:team, name: "C-Team")

        get :index

        assert_select 'a', text: /A-Team/
        assert_select 'a', text: /B-Team/
        assert_select 'a', text: /C-Team/
    end

    test "team members" do
        team = create(:team)
        3.times do |n|
            user = create(:user, username: "Player#{n + 1}")
            team.invite!(user)
            team.mark_invitation!(user, true)
        end

        get :show, id: team.to_param

        assert_select 'a', text: /Player1/
        assert_select 'a', text: /Player2/
        assert_select 'a', text: /Player3/
    end

    test "create team" do
        user = create(:user)
        sign_in user

        assert_created Team do
            post :create, team: {name: "MyTeam"}
        end

        assert_equal user, Team.find_by(name: "MyTeam").leader
    end

    test "update team" do
        team = create(:team, name: "OldName")
        sign_in team.leader

        post :update, id: team.id, team: {name: "NewName"}

        assert_equal "NewName", team.reload.name
    end

    test "register team for tournament" do
        Group.default_group.web_permissions = {'tournament' => {'participate' => true}}

        team = create(:team)
        sign_in team.leader

        user = create(:user)
        team.invite!(user)
        team.mark_invitation!(user, true)

        tourney = create(:tournament)

        post :submit_registration, team_id: team.id, tournament: tourney.id, registration: {members: {user.id => '1'} }

        assert_no_alerts
        assert tourney.team_registered?(team.reload)
    end
end
