class Death
    include Mongoid::Document
    include BackgroundIndexes
    include ApiModel
    include ApiSearchable
    include ApiAnnounceable
    include User::Legacy::Macros

    store_in database: 'oc_deaths'

    belongs_to :match
    belongs_to :server
    field :family, type: String
    field :date, type: Time, default: Time.now

    belongs_to_legacy_user relation:   :victim_obj,
                           external:   :victim_id,
                           internal:   :victim,
                           inverse_of: :deaths

    belongs_to_legacy_user relation:   :killer_obj,
                           external:   :killer_id,
                           internal:   :killer,
                           inverse_of: :kills

    field :entity_killer, type: String
    field :block_killer, type: String
    field :player_killer, type: Boolean
    field :teamkill, type: Boolean

    field :distance, type: Float
    field :weapon, type: String
    field :enchanted, type: Boolean
    field :from, type: String
    field :action, type: String
    field :cause, type: String

    field :x, type: Float
    field :y, type: Float
    field :z, type: Float

    field :victim_class, type: String
    field :killer_class, type: String

    attr_accessor :raindrops # not saved

    required = [:match_id, :server_id, :family, :date, :victim_id, :x, :y, :z]
    optional = [
        :killer_id, :entity_killer, :block_killer, :teamkill, :player_killer,
        :distance, :weapon, :enchanted, :from, :action, :cause,
        :victim_class, :killer_class
    ]

    attr_accessible :_id, :victim, :killer, :raindrops, *required, *optional
    validates_presence_of :victim_obj, *required
    api_property *required, *optional

    api_synthetic :victim do
        victim_obj.api_player_id
    end

    api_synthetic :killer do
        killer_obj.api_player_id if killer
    end

    index!(INDEX_family = {family: 1})
    index!(INDEX_server = {server_id: 1})
    index!(INDEX_match = {match_id: 1})
    index!(INDEX_date = {date: -1})
    index!(INDEX_victim = {metadata(:victim_obj).name => 1, date: -1})
    index!(INDEX_killer = {metadata(:killer_obj).name => 1, date: -1})

    scope :victim, -> (user) { where!(victim_obj: user).hint(INDEX_victim) }
    scope :killer, -> (user) { where!(killer_obj: user).hint(INDEX_killer) }
    scope :kills, where!(killer_obj: {$ne => nil}).hint(INDEX_killer)
    scope :killed, -> (user) { kills.victim(user) }
    scope :team_kill, -> (yes) { if yes then where!(teamkill: true) else where!(teamkill: {$ne => true}) end }
    scope :after, -> (date) { gt(date: date).hint(INDEX_date) }

    class << self
        def search_request_class
            DeathSearchRequest
        end

        def search_results(request: nil, documents: nil)
            documents = super
            hint = INDEX_date

            if request
                if request.victim
                    documents = documents.where(victim_id: request.victim)
                    hint = INDEX_victim
                elsif request.killer
                    documents = documents.where(killer_id: request.killer)
                    hint = INDEX_killer
                end
            end

            documents.desc(:date).hint(hint)
        end

        def join_users(deaths = all, users: User.all)
            deaths = deaths.to_a

            player_ids = []
            deaths.each do |death|
                player_ids << death.victim_id if death.victim_id && !death.relation_set?(:victim_obj)
                player_ids << death.killer_id if death.killer_id && !death.relation_set?(:killer_obj)
            end

            unless player_ids.empty?
                users_by_player_id = users.in(player_id: player_ids.uniq).index_by(&:player_id)

                deaths.each do |death|
                    death.set_relation(:victim_obj, users_by_player_id[death.victim_id]) if death.victim_id && !death.relation_set?(:victim_obj)
                    death.set_relation(:killer_obj, users_by_player_id[death.killer_id]) if death.killer_id && !death.relation_set?(:killer_obj)
                end
            end

            deaths
        end

        def join_matches(deaths = all, matches: Match.all)
            deaths = deaths.to_a

            match_ids = deaths.select{|death| death.match_id && !death.relation_set?(:match) }.map(&:match_id)

            unless match_ids.empty?
                matches_by_id = matches.in(id: match_ids.uniq).index_by(&:id)

                deaths.each do |death|
                    death.set_relation(:match, matches_by_id[death.match_id]) if death.match_id && !death.relation_set?(:match)
                end
            end

            deaths
        end
    end

    def killer_name
        if killer_obj
            killer_obj.username
        elsif entity_killer
            entity_killer
        elsif block_killer
            block_killer
        end
    end
end
