FactoryGirl.define do
    factory :forum, class: Forem::Forum do
        sequence(:title) {|n| "Forum#{n}" }
        category { create(:category) }
    end
end
