module GlobalFixtures
    extend ActiveSupport::Concern

    included do
        setup do
            create(:default_group, permissions: [['site', 'login', true]])
            create(:participant_group)
            create(:observer_group)
            create(:trial_group)
            create(:mapmaker_group)
        end
    end
end
