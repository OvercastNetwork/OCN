require 'test_helper'

class TeamTest < ActiveSupport::TestCase
    test "normalization and defaults" do
        leader = create(:user)
        team = Team.create!(name: "Team Name", leader: leader)

        team.reload
        assert_equal "teamname", team.name_normalized
        assert team.is_member?(leader), "Leader should automatically join the team"
    end

    test "joining" do
        team = create(:team)
        member = create(:user)
        tryout = create(:user)

        team.invite!(member)
        team.mark_invitation!(member, true)
        team.invite!(tryout)
        team.reload

        assert_set [team.leader, tryout, member], team.members.map(&:user)
        assert team.is_member?(member)
        assert team.is_member?(tryout)

        assert_set [team.leader, member], team.accepted_members.map(&:user)
        assert team.is_accepted_member?(member)
        refute team.is_accepted_member?(tryout)
        assert_equal 2, team.member_count

        assert_set [tryout], team.pending_members.map(&:user)
        assert team.is_invited?(tryout)
        refute team.is_invited?(member)

    end

    test "accept invite" do
        team = create(:team)
        user = create(:user)

        team.invite!(user)
        team.mark_invitation!(user, true)
        team.reload

        assert team.is_accepted_member?(user)
    end

    test "decline invite" do
        team = create(:team)
        user = create(:user)

        team.invite!(user)
        team.mark_invitation!(user, false)
        team.reload

        refute team.is_accepted_member?(user)
        refute team.is_member?(user)
    end

    test "eject member from team" do
        user = create(:team_member)
        team = user.team

        tourney = create(:tournament)
        tourney.register_team!(team, [user])

        team.eject!(user)

        refute team.is_member?(user)
        refute_member tourney.entrant_for(team).confirmed_users, user
    end

    test "disband" do
        team = create(:team)
        team.leave!(team.leader)
        assert team.reload.dead?
    end

    test "cannot disband with members" do
        team = create(:team)
        user = create(:user)
        team.invite!(user)
        team.mark_invitation!(user, true)

        assert_raises Mongoid::Errors::Validations do
            team.die!
        end
    end

    test "team name is unique" do
        create(:team, name: "Woot")
        assert_raises Mongoid::Errors::Validations do
            Team.create!(name: "wOOT")
        end
    end

    test "disbanded team name can be reused" do
        team = create(:team, name: "Woot")
        team.leave!(team.leader)

        team = Team.create!(name: "Woot", leader: create(:user))
        assert_valid team
    end
end
