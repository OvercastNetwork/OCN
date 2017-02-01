class Match
    include Mongoid::Document
    include BackgroundIndexes
    store_in :database => "oc_matches"

    include ApiModel
    include ApplicationHelper

    attr_accessible :_id # PGM generates the ID


    # Timestamps

    field :load,    type: Time
    field :start,   type: Time
    field :end,     type: Time
    field :unload,  type: Time

    field :skipped, type: Boolean, default: false # Match unloaded without starting

    [:load, :start, :end, :unload].each do |verb|
        alias_method "#{verb}ed_at", verb
        alias_method "#{verb}ed?", verb
    end

    attr_accessible :load, :start, :end, :unload

    validates :load, presence: true

    validates :start, time: {after: :load, if: :started?},
              presence: {if: :ended?}

    validates :end, time: {after: :start, if: :ended?},
              presence: {if: -> { started? && unloaded? }}

    validates :unload, time: {after: :load, if: :unloaded?}
    validates :unload, time: {after: :end, if: -> { ended? && unloaded? }}

    scope :hint_unload, -> { hint(unload: 1) }
    scope :loaded, -> { where(unload: nil).hint_unload }

    scope :started, -> (yes = true) { yes ? ne(start: nil) : where(start: nil) }
    scope :ended, -> (yes = true) { yes ? ne(end: nil) : where(end: nil) }
    scope :running, -> { loaded.started(true).ended(false) }

    scope :loaded_or_played, ne(skipped: true)
    scope :recent, gt(load: 1.week.ago) # Only point of this is to keep the queries fast

    # Server/Family

    belongs_to :family
    belongs_to :server, inverse_of: :fucking_matches

    validates :family, reference: true
    validates :server, reference: true

    attr_accessible :family, :family_id, :server, :server_id

    scope :server, -> (s) { where(server: s) }
    scope :servers, -> (s) { self.in(server_id: s.map(&:id)) }


    # Map

    belongs_to :map
    validates :map, reference: true
    accepts_nested_attributes_for :map # Allow map to be updated through a match

    attr_accessible :map, :map_id


    # Other relations

    has_many :participations
    has_many :deaths
    has_many :engagements


    # Winners

    field :winning_team_ids, type: Array, default: [].freeze
    has_and_belongs_to_many :winning_users, class_name: 'User', inverse_of: nil

    attr_accessible :winning_team_ids, :winning_user_ids

    validates :winning_users, reference: true
    validates_each :winning_team_ids do |match, _, ids|
        missing = ids.to_a.reject{|id| match.competitors.find(id) }
        unless missing.empty?
            match.errors.add(:winning_team_ids, "contains unknown team IDs: #{missing.map(&:inspect).join(', ')}")
        end
    end


    # Player counts

    field :player_count, type: Integer, default: 0
    attr_accessible :player_count
    validates :player_count, presence: true

    # Joining

    field :join_mid_match, type: Boolean, default: true
    attr_accessible :join_mid_match

    # Competitors

    embeds_many :competitors, class_name: 'Match::Team'
    attr_accessible :competitors
    accepts_nested_attributes_for :competitors

    class Team < Map::Team
        include Mongoid::Document
        embedded_in :match

        field :size, type: Integer
        belongs_to :league_team, class_name: 'Team'

        attr_accessible :_id, :size, :league_team_id
        api_property :size, :league_team_id

        def map_team
            match.map.teams.find(id)
        end
    end


    # Objectives

    embeds_many :objectives, class_name: 'Match::Objective'
    attr_accessible :objectives
    accepts_nested_attributes_for :objectives

    class Objective
        include Mongoid::Document
        include ApiModel
        embedded_in :match

        field :_id, type: String, overwrite: true # PGM objective ID
        field :type, type: String
        field :name, type: String

        # OwnedGoal
        field :owner_id, type: String # PGM team ID
        field :owner_name, type: String

        # IncrementalGoal
        field :completion, type: Float

        # TouchableGoal
        embeds_many :proximities, class_name: 'Match::Objective::Proximity'
        accepts_nested_attributes_for :proximities

        class Proximity
            include Mongoid::Document
            include ApiModel
            embedded_in :objective, class_name: 'Match::Objective'

            class Metric < Enum
                create :CLOSEST_PLAYER, :CLOSEST_BLOCK, :CLOSEST_KILL,
                       :CLOSEST_PLAYER_HORIZONTAL, :CLOSEST_BLOCK_HORIZONTAL, :CLOSEST_KILL_HORIZONTAL
            end

            field :_id, type: String, overwrite: true # PGM team ID
            field :touched, type: Boolean
            field :metric, type: Metric, allow_nil: true
            field :distance, type: Float

            properties = :touched, :metric, :distance
            attr_accessible :_id, *properties
            api_property *properties
        end

        # Destroyable
        field :total_blocks, type: Integer
        field :breaks_required, type: Integer
        field :breaks, type: Integer

        properties = [:type, :name, :owner_id, :owner_name,
                      :completion, :proximities,
                      :total_blocks, :breaks_required, :breaks]
        attr_accessible :_id, *properties
        api_property *properties
    end

    # Mutations

    class Mutation < Enum
        create :BLITZ, :UHC, :EXPLOSIVES, :NO_FALL, :MOBS, :STRENGTH, :DOUBLE_JUMP, :INVISIBILITY, :LIGHTNING, :RAGE, :ELYTRA
    end

    field :mutations, type: Array, default: [].freeze
    attr_accessible :mutations

    # Legacy fields
    field :teams, type: Hash            # replaced by :competitors
    field :goals, type: Hash            # replaced by :objectives
    field :winning_team, type: String   # replaced by :winning_team_ids

    index({load: 1})
    index({start: 1})
    index({end: 1})
    index({unload: 1})
    index({skipped: 1})
    index({relations['map'].key => 1, load: -1})
    index({relations['server'].key => 1, start: 1, end: -1})
    index({relations['server'].key => 1, load: -1})
    index({skipped: 1, load: -1})
    index({skipped: 1, relations['map'].key => 1, load: -1})
    index({skipped: 1, relations['server'].key => 1, load: -1})

    api_property :server_id, :family_id,
                 :map, :competitors, :objectives, :mutations,
                 :load, :start, :end, :unload,
                 :winning_team_ids, :winning_user_ids,
                 :player_count,
                 :join_mid_match

    before_validation do
        self.skipped = !!(unloaded? && !started?)
        self.family ||= server.family if server
        true
    end

    class << self
        def unload!(time = Time.now)
            self.loaded.update_all(unload: time)
        end

        def left_join_maps(maps = Map.all, matches: all)
            matches = matches.to_a
            maps = maps.in(_id: matches.map(&:map_id))
            maps_by_id = maps.index_by(&:id)

            matches.each do |match|
                if map = maps_by_id[match.map_id]
                    match.set_relation(:map, map)
                end
            end

            matches
        end
    end

    def map_slug
        map.slug if map
    end

    def map_name
        if map
            map.name
        else
            "Unknown Map"
        end
    end

    def map_version
        map.version
    end

    def when_text
        if unloaded?
            time_ago_in_words(unload, false, vague: true) + " ago"
        elsif ended?
            "Finished"
        elsif started?
            "Running"
        else
            "Starting"
        end
    end

    def length
        minutes = self.length_in_minutes
        seconds = (self.length_in_seconds - (minutes * 60)).to_s

        if minutes.to_s.length == 1
            minutes = "0" + minutes.to_s
        end

        if seconds.length == 1
            seconds = "0" + seconds
        end

        minutes.to_s + ":" + seconds.to_s
    end

    def duration
        length_in_seconds.seconds
    end

    def length_in_seconds
        if started?
            ((self.end || Time.now) - start).to_i
        else
            0
        end
    end

    def length_in_minutes
        (length_in_seconds / 60).to_i
    end

    def loaded?
        load? && !unload?
    end

    def running?
        loaded? && start? && !end?
    end

    def participating_players
        participations.map(&:player).compact.uniq
    end

    def winning_team_ids
        attributes['winning_team_ids'].to_a
    end

    def winning_teams
        winning_team_ids.map{|team_id| competitors.find(team_id) }.compact
    end

    def set_valid!(valid)
        request = EngagementUpdateRequest.new(engagements.map{|eng| {_id: eng.id, ignored: !valid} })
        Publisher::DIRECT.publish(request)
    end
end
