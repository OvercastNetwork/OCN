module PlayerStat
    extend ActiveSupport::Concern

    # Mongoid does not provide an "abstract document" mechanism, so this is
    # an ad-hoc implementation of it. PlayerStat is not a Document itself,
    # but when it's included in a Class, it brings Document with it as well
    # as the declarations in the method below.
    #
    # This is used to create different PlayerStat models for different time
    # spans, each stored in a different collection.
    #
    # It would be nice if Mongoid did this itself when you include Document
    # in another module, but doing that just raises an error.

    FAMILIES = %w[
        global
        pgm-public
        mini
        blitz-public
        gs-public
        micro
        arcade
        skywars
        survival
    ]

    TOTALS = %w[
        playing_time
        deaths
        deaths_player
        deaths_team
        kills
        kills_team
        wool_placed
        cores_leaked
        destroyables_destroyed
    ]

    RATES = %w[
        kd
        kk
        tkrate
    ]

    RECENTS = %w[
        last_death
        last_kill
        last_wool_placed
        last_core_leaked
        last_destroyable_destroyed
    ]

    STATS = [*TOTALS, *RATES, *RECENTS]

    OBJECTIVES = %w[
        wool_placed
        cores_leaked
        destroyables_destroyed
    ]

    # We only index what we show. Make sure to update this
    # if we ever change what we show.
    #
    # We don't show global, but we use it for other things.

    INDEXED_FAMILIES = %w[
        global
        pgm-public
        mini
        blitz-public
        micro
        arcade
        skywars
        survival
    ]

    INDEXED_STATS = %w[
        playing_time
        kills
        deaths
        deaths_player
    ]

    included do
        if is_a? Class
            store_in :database => "oc_playerstats"

            field :_id, type: String, overwrite: true
            field :value, :type => Hash, :default => {}.freeze

            attr_accessible :_id, :value
        end
    end

    module ClassMethods
        def for_user(user)
            find(user.player_id)
        end

        def find_or_new_for_user(user)
            for_user(user) || new(_id: user.player_id)
        end

        def stat_path(stat, family = nil)
            "value.#{@timespan}.#{family || 'global'}.#{stat}"
        end

        def order_spec(stat, family = nil)
            # Resolve ties with _id, so sort is stable
            {stat_path(stat, family) => -1, '_id' => 1}
        end

        def timespan(span = nil)
            if span
                @timespan = span.to_s

                # Generate indexes
                INDEXED_FAMILIES.each do |family|
                    INDEXED_STATS.each do |stat|
                        index(order_spec(stat, family), {background: true})
                    end
                end
            end

            @timespan
        end

        def order_by_stat(stat, family = nil)
            spec = order_spec(stat, family)
            order_by(spec).hint(spec)
        end
    end

    class Daily
        include Mongoid::Document
        include PlayerStat
        store_in :collection => "player_stats_day"
        timespan :day
    end

    class Weekly
        include Mongoid::Document
        include PlayerStat
        store_in :collection => "player_stats_week"
        timespan :week
    end

    class Eternal
        include Mongoid::Document
        include PlayerStat
        store_in :collection => "player_stats_eternity"
        timespan :eternity
    end

    def self.for_period(period)
        case period.to_s
            when 'day'      then Daily
            when 'week'     then Weekly
            when 'eternity' then Eternal
        end
    end

    def playing_time(family = nil)
        (playing_time_ms(family) / 1000).seconds
    end

    def playing_time_ms(family = nil)
        stat(:playing_time, family)
    end

    def stat(stat, family = nil)
        (families = self.value[self.class.timespan] and
            stats = families[(family || :global).to_s] and
            stats[stat.to_s]) or 0
    end

    def pretty_stat(stat, family = nil)
        total = stat(stat, family)
        if %w[kd kk tkrate].include? stat.to_s
            total.round(3)
        else
            total.to_i
        end
    end

    def ordinal(stat, family = nil)
        path = self.class.stat_path(stat, family)
        value = stat(stat, family)
        self.class
            .order_by_stat(stat, family)
            .or({path => {$gt => value}},
                {path => value, :_id => {$lt => id}})
            .count + 1
    end

    def rank(stat, family = nil)
        self.class
            .order_by_stat(stat, family)
            .gt(self.class.stat_path(stat, family) => stat(stat, family))
            .count + 1
    end

    def set(stat, family = nil, n)
        stat = stat.to_s
        family = (family || :global).to_s

        value[self.class.timespan] ||= {}
        value[self.class.timespan][family] ||= {}
        value[self.class.timespan][family][stat] = n
    end
end
