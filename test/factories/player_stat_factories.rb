FactoryGirl.define do
    factory :stats, class: PlayerStat::Eternal do
        _id { create(:user).player_id }
    end
end
