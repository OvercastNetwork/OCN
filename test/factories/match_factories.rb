FactoryGirl.define do
    factory :match, class: Match do
        load { Time.now }
        server { create(:server) }
        family_id { server.family }
        map { create(:map) }

        factory :team_match do
            map { create(:team_map) }

            transient do
                league_teams { [] }
            end

            after(:build) do |match, args|
                match.map.teams.each_with_index do |map_team, i|
                    match_team = create(:match_team, match: match, _id: map_team.id)
                    if league_team = args.league_teams[i]
                        match_team.league_team = league_team
                    end
                    match.competitors << match_team
                end
            end
        end
    end

    factory :match_team, class: Match::Team do
        after(:build) do |match_team, args|
            map_team = match_team.map_team
            league_team = match_team.league_team
            match_team.name = league_team ? league_team.name : map_team.name
            match_team.color = map_team.color
            match_team.min_players = map_team.min_players
            match_team.max_players = map_team.max_players
            match_team.size = map_team.max_players
        end
    end
end
