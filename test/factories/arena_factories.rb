FactoryGirl.define do
    factory :arena do
        game { create(:game) }
        datacenter 'US'
    end
end
