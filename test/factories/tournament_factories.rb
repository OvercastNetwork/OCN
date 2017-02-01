FactoryGirl.define do
    factory :tournament do
        sequence(:name) {|n| "Tournament#{n}" }
        url { self.name.slugify }
        details { "#{self.name} details" }

        self.end { 1.week.from_now }
        registration_start { 1.day.ago }
        registration_end { 1.day.from_now }

        min_players_per_team 1
        max_players_per_team 10
    end
end
