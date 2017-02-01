FactoryGirl.define do
    factory :group, class: Group do
        sequence(:name) { |n| "Group#{n}" }

        transient do
            permissions []
            members []
        end

        after(:build) do |group, evaluator|
            root = {}
            evaluator.permissions.to_a.each do |permission|
                permission = Permissions.expand(*permission)
                *prefix, key, value = permission
                tree = root
                prefix.each do |node|
                    tree = (tree[node] ||= {})
                end
                tree[key] = value
            end
            group.web_permissions = root
        end

        after(:create) do |group, evaluator|
            evaluator.members.to_a.each do |member|
                member.join_group(group)
            end
        end

        factory :default_group do
            name Group::DEFAULT_GROUP_NAME
            priority 1000
        end

        factory :observer_group do
            name Group::OBSERVER_GROUP_NAME
            priority 900
        end

        factory :participant_group do
            name Group::PARTICIPANT_GROUP_NAME
            priority 800
        end

        factory :trial_group do
            name User::Premium::TRIAL_GROUP_NAME
        end

        factory :mapmaker_group do
            name Group::MAPMAKER_GROUP_NAME
        end

        factory :premium_group do
            after(:create) do |group, evaluator|
                create(:package, group: group)
            end
        end

        factory :gizmo do
            transient do
                sequence(:name) { |n| "gizmo#{n}" }
            end

            initialize_with do
                Group.for_gizmo(name).build
            end
        end

        factory :staff_group do
            staff true
            minecraft_permissions 'pgm-public' => ['projectares.staff']
        end
    end
end
