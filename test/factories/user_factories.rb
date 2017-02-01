
def random_uuid
    User.normalize_uuid(UUIDTools::UUID.random_create.to_s)
end

FactoryGirl.define do
    factory :unregistered_user, class: User do
        # A user who has played on the server but not registered on the website
        sequence(:username) { |n| "Player#{n}" }
        username_verified_at { Time.now }
        uuid { random_uuid }

        after :build do |user|
            user.player_id = "_#{user.id}"
            user.usernames = [User::Identity::Username.new(exact: user.username)]
        end

        factory :user do
            # A user who has registered on the website
            sequence(:email) { |n| "player#{n}@example.com" }
            password 'password'

            after(:build) do |user|
                user.skip_confirmation!
                user.apply_defaults
            end

            factory :staff_member do
                after(:create) do |user|
                    user.join_group(create(:staff_group))
                end
            end

            factory :friend do
                transient do
                    of { create(:user) }
                end

                after(:create) do |user, args|
                    fs = Friendship.new(friender: user,
                                        friended: args.of,
                                        decision: true)
                    fs.sent_date = fs.decision_date = Time.now
                    fs.save!
                end
            end

            factory :team_member do
                transient do
                    team { create(:team) }
                end

                after(:create) do |user, args|
                    args.team.invite!(user)
                    args.team.mark_invitation!(user, true)
                end
            end
        end
    end
end
