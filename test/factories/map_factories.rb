FactoryGirl.define do
    factory :map, class: Map do
        sequence(:name) {|n| "Map#{n}" }
        version [1,0]
        gamemode [:mixed]

        factory :team_map do
            after(:build) do |map, args|
                map.teams << create(:map_team, name: "Red Team", map: map)
                map.teams << create(:map_team, name: "Blue Team", map: map)
            end
        end
    end

    factory :map_team, class: Map::Team do
        sequence(:name) {|n| "Team#{n}" }
        _id { name.slugify }
        sequence(:color) {|n| ChatColor::COLORS[n % ChatColor::COLORS.size].name }
        min_players 1
        max_players 16
    end
end
