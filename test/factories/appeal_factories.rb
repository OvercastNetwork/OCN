FactoryGirl.define do
    factory :appeal do
        authorized_ip "1.2.3.4"

        transient do
            punishments { [create(:punishment)] }
        end

        after(:build) do |appeal, evaluator|
            evaluator.punishments.to_a.each do |punishment|
                appeal.add_excuse(punishment, "Reason for punishment #{punishment.id}")
                appeal.punished ||= punishment.punished
            end

            appeal.punished ||= create(:user)
        end
    end
end
