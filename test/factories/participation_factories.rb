FactoryGirl.define do
    factory :participation, class: Participation do
        server { create(:server) }
        match { create(:match, server: server) }
        user { create(:user) }
        session { create(:session, server: server, user: user) }

        team_id "Team"
        start { Time.now }
    end
end
