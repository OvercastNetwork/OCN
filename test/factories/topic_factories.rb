FactoryGirl.define do
    factory :topic, class: Forem::Topic do
        sequence(:subject) {|n| "Topic#{n}" }
        forum { create(:forum) }
        user { create(:user) }
    end
end
