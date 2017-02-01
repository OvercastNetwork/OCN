FactoryGirl.define do
    factory :team do
        sequence(:name) {|n| "Team#{n}" }
        leader { create(:user, username: "#{name.slugify}Leader") }

        factory :team_of2 do
            after(:build) do |team|
                team.join(create(:user, username: "#{name.slugify}Member"), accepted: true)
            end
        end
    end
end
