FactoryGirl.define do
    factory :category, class: Forem::Category do
        sequence(:name) {|n| "Category#{n}" }
    end
end
