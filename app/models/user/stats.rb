class User
    # See also #PlayerStat
    module Stats
        extend ActiveSupport::Concern

        def stats
            @stats_eternal ||= PlayerStat::Eternal.find_or_new_for_user(self)
        end

        def stats_weekly
            @stats_weekly ||= PlayerStat::Weekly.find_or_new_for_user(self)
        end

        def stats_daily
            @stats_daily ||= PlayerStat::Daily.find_or_new_for_user(self)
        end
    end # Stats
end
