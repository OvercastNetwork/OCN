FactoryGirl.define do
    factory :game do
        sequence(:_id) { |n| "game#{n}" }
        sequence(:name) { |n| "Game#{n}" }
        priority 0
        network Server::Network::PUBLIC
        visibility Server::Visibility::PUBLIC

        initialize_with do
            Game.find(_id) || new(attributes)
        end
    end
end
