FactoryGirl.define do
    factory :death do
        date { Time.now }
        match { create(:match) }
        server { match.server }
        family { server.family }
        victim_obj { create(:user) }
        x 0
        y 0
        z 0
    end
end
