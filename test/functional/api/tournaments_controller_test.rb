require 'test_helper'

module Api
    class TournamentsControllerTest < ActionController::TestCase
        include ModelControllerFindTest

        tests TournamentsController

        def create_stuff
            @tourney = create(:tournament)
            @teams = create_list(:team, 2)
            @teams.each do |team|
                @tourney.register_team!(team, [])
                @tourney.accept_team!(team)
            end
            @entrants = @teams.map{|team| @tourney.entrant_for(team) }
        end

        test "list teams" do
            create_stuff

            get :teams, id: @tourney.id

            assert_json_collection(documents: @teams.map{|team| {
                _id: team.id,
                name: team.name,
                name_normalized: team.name_normalized
            }})
        end

        test "find entrant by team ID" do
            create_stuff

            get :entrants, id: @tourney.id, team_id: @teams[0].id

            assert_json_response(
                team: @teams[0].api_document,
                members: @entrants[0].confirmed_users.map(&:api_player_id),
                matches: []
            )
        end

        test "find entrant by team name" do
            create_stuff

            get :entrants, id: @tourney.id, team_name: @teams[0].name

            assert_json_response @entrants[0].api_document
        end

        test "find entrant by member" do
            create_stuff

            get :entrants, id: @tourney.id, member_id: @teams[1].leader.id

            assert_json_response @entrants[1].api_document
        end

        test "record match" do
            create_stuff
            match = create(:team_match, league_teams: @teams)

            post :record_match, id: @tourney.id, match_id: match.id

            @teams.each do |team|
                assert_set [match], @tourney.entrant_for(team.reload).official_matches
            end
        end
    end
end
