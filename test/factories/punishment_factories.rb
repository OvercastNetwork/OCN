FactoryGirl.define do
    factory :punishment do
        type Punishment::Type::BAN
        sequence(:reason)       {|n| "Reason for punishment #{n}" }
        sequence(:punished)     {|n| create(:user, username: "BadPlayer#{n}") }
        sequence(:punisher)     {|n| create(:user, username: "Moderator#{n}") }
        sequence(:server)       {|n| create(:server, name: "Punishment Server #{n}") }

        factory :warn do
            type Punishment::Type::WARN
        end

        factory :kick do
            type Punishment::Type::KICK
        end

        factory :ban do
            type Punishment::Type::BAN
        end

        factory :forum_warn do
            type Punishment::Type::FORUM_WARN
        end

        factory :forum_ban do
            type Punishment::Type::FORUM_BAN
        end
    end
end
