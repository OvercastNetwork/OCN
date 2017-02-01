class User
    module Engagements
        extend ActiveSupport::Concern

        included do
            has_many :engagements
            api_synthetic :recent_match_joins_by_family_id
        end

        def recent_match_joins_by_family_id(interval: 1.day)
            engagements
            .ignored(false)
            .gte(match_joined_at: interval.ago)
            .desc(:match_joined_at)
            .group_by(&:family)
            .mash{|family, engs| [family.id, engs.map(&:match_joined_at)] }

        end

        def recent_match_joins(family:, interval: 1.day)
            engagements.ignored(false).family(family).gte(match_joined_at: interval.ago).desc(:match_joined_at).map(&:match_joined_at)
        end

        def engagement_commitment
            # This query needs a hint or Mongo sometimes caches a bad plan
            e = engagements.unfinished.committed.ignored(false).desc(:match_joined_at).hint_effective_at.first
            e if e && e.match && e.match.running?
        end

        def match_commitment
            e = engagement_commitment and e.match
        end

        def server_commitment
            m = match_commitment and m.server
        end
    end
end
