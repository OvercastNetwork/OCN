
FactoryGirl.define do
    factory :package do
        sequence(:name) { |n| "Package#{n}" }
        price 0
        priority 0

        before(:create) do |package|
            package.group ||= create(:group, name: "Group for #{package.name}")
        end

        factory :public_package do
            factory :optio do
                name 'Optio'
                price 1000
                time_limit 60.days
            end

            factory :centurion do
                name 'Centurion'
                price 2500
                time_limit 180.days
            end

            factory :dux do
                name 'Dux'
                price 5000
            end
        end
    end
end
