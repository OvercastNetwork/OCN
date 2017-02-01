FactoryGirl.define do
    factory :post, class: Forem::Post do
        sequence(:text) {|n| "Post#{n}" }
        topic { create(:topic) }

        after(:build) do |post, _|
            post.user ||= post.topic.user
        end
    end
end
