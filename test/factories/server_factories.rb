FactoryGirl.define do
    factory :server do
        sequence(:name) { |n| "Server#{n}" }
        bungee_name { self.name.downcase }
        family { create(:pgm_family).id }
        network Server::Network::PUBLIC
        role Server::Role::PGM
        realms %w(global pgm-public)
        datacenter 'US'
        box 'box01'
        ip 'box01.lan'
        port 25565
        min_players 1
        max_players 8

        factory :lobby do
            sequence(:name) { |n| "Lobby#{n}" }
            family { create(:lobby_family).id }
            role Server::Role::LOBBY
        end

        factory :bungee do
            sequence(:name) { |n| "Bungee#{n}" }
            family { create(:bungee_family).id }
            role Server::Role::BUNGEE
        end

        factory :game_server do
            online true
            game { create(:arena, datacenter: self.datacenter).game }

            after :create do |server|
                server.current_match = create(:match, server: server)
                server.current_map = server.current_match.map
                server.save!
            end
        end
    end
end
