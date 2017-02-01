FactoryGirl.define do
    factory :family do
        sequence(:_id) { |n| "family#{n}" }
        sequence(:name) { |n| "Family#{n}" }

        initialize_with do
            Family.find(_id) || new(attributes)
        end

        factory :pgm_family do
            _id 'pgm-public'
            name 'Project Ares'
            priority 1
            send :public, true
        end

        factory :lobby_family do
            _id 'lobby-public'
            name 'Lobby'
            priority 3
            send :public, true
        end

        factory :bungee_family do
            _id 'bungee'
            name 'Bungee'
            priority 10
            send :public, false
        end
    end
end
