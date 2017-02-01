class EngagementWorker
    include QueueWorker

    queue :engagements, durable: true
    consumer exclusive: true

    MINIMUM_INTERVAL = 10.seconds

    def save_engagements(engagement_attrs)
        engagements = []
        created = updated = finalized = 0
        now = Time.now.utc

        engagement_attrs.each do |attrs|
            id = attrs['_id']
            eng  = Engagement.find(id)
            if eng
                eng.update_attributes!(attrs)
                updated += 1
            else
                eng = Engagement.new(attrs)
                eng.id = id
                created += 1
            end

            if eng.finished? && eng.effective_at.nil?
                eng.effective_at = now
                finalized += 1
            end

            eng.save!
            engagements << eng
        end

        map_ids = engagements.map(&:map_id).uniq.compact

        logger.info("Saved #{engagements.size} engagements for map #{map_ids.join(', ')} (created=#{created} updated=#{updated} finalized=#{finalized})")

        engagements
    end

    startup do
        if ranking = Ranking.by_last_match_time(-1).first
            process_engagements(Engagement.gte(effective_at: ranking.value.last_match_at))
        end
    end

    handle EngagementUpdateRequest do |msg|
        process_engagements(save_engagements(msg.engagements))
        ack!(msg)
    end

    def process_engagements(engagements)
        user_ids = Set[]
        Ranking.relevant_engagements(engagements).each do |eng|
            user_ids << eng.user_id if eng.finished?
        end

        unless user_ids.empty?
            logger.info("Aggregating stats for #{user_ids.size} users with new matches")
            Ranking.recalculate_for_user_ids(user_ids)
            refresh_and_schedule_next
        end
    end

    def next_refresh_at
        @next_refresh_at || Time::INF_FUTURE
    end

    def refresh_at(time)
        if time < next_refresh_at
            @next_refresh_at = time
            true
        else
            false
        end
    end

    poll delay: MINIMUM_INTERVAL do
        if next_refresh_at <= Time.now
            refresh_and_schedule_next
        end
    end

    def schedule_next_refresh(now = Time.now.utc)
        if ranking = Ranking.first_non_stale(now)
            time = [ranking.stale_at, now + MINIMUM_INTERVAL].max
            if refresh_at(time)
                logger.info("Scheduling next refresh for #{time}")
            end
        else
            logger.info("No fresh rankings, refresh not scheduled")
        end
    end

    def refresh_and_schedule_next(now = Time.now.utc)
        rankings = Ranking.stale(now)
        count = rankings.count
        if count > 0
            logger.info("Refreshing #{count} rankings with expired matches")
            rankings.recalculate
        end
        schedule_next_refresh(now)
    end
end
