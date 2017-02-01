FactoryGirl.define do
    factory :open_session, class: Session do
        player { create(:user) }
        server { create(:server) }
        start { Time.now.utc }
        ip { "1.2.3.4" }

        factory :session do
            self.end { Time.now }
        end
    end
end
