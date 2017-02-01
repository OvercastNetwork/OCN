class Engagement
    include Mongoid::Document
    include Mongoid::Timestamps
    include BackgroundIndexes
    store_in :database => "oc_engagements"

    include ApiModel

    # Guaranteed monotonic timestamp created by the engagement worker
    # Should be roughly the same time the match finished, or nil if match is unfinished
    field :effective_at, type: Time
    scope :hint_effective_at, hint(effective_at: 1)
    scope :unfinished, where(effective_at: nil)
    scope :finished, ne(effective_at: nil)

    field :ignored, type: Boolean, default: false
    scope :ignored, ->(yes) { if yes then where(ignored: true) else ne(ignored: true) end }

    belongs_to :family, index: true, reference: true
    field_scope :family
    belongs_to :server, index: true, reference: true
    belongs_to :user, index: true, reference: true
    belongs_to :match, index: true, reference: true

    field :match_started_at, type: Time
    field :match_joined_at, type: Time
    field :match_finished_at, type: Time
    field :match_length, type: ActiveSupport::Duration
    field :match_participation, type: ActiveSupport::Duration
    field :match_participation_percent, type: Float

    # Player is forced to join/stay in the match (currently always true)
    field :committed, type: Boolean, default: true
    scope :committed, ne(committed: false)

    belongs_to :map, index: true
    validates_presence_of :map_id # Validate map_id but not map, in case the map hasn't been synced to the DB
    field :map_version, type: Array, allow_nil: false

    field :genre, type: Map::Genre, allow_nil: false
    field_scope :genre

    field :player_count, type: Integer
    field :competitor_count, type: Integer

    field :team_pgm_id, type: String
    field :team_size, type: Integer
    field :team_participation, type: ActiveSupport::Duration
    field :team_participation_percent, type: Float

    field :rank, type: Integer                  # Competitive rank in the match, leaders have rank 0
    field :tied_count, type: Integer            # Number of competitors with this rank (including self)

    class ForfeitReason < Enum
        create :ABSENCE, :PARTICIPATION_PERCENT, :CUMULATIVE_ABSENCE, :CONTINUOUS_ABSENCE
    end
    field :forfeit_reason, type: ForfeitReason, allow_nil: true
    scope :forfeits, ne(forfeit_reason: nil)

    index_asc :effective_at, :map_version, :match_joined_at, :match_finished_at, :genre, :team_pgm_id, :ignored

    properties = [
        :family_id, :server_id, :user_id, :match_id,
        :match_started_at, :match_joined_at, :match_finished_at, :match_length, :match_participation,
        :committed,
        :map_id, :map_version, :genre,
        :player_count, :competitor_count,
        :team_pgm_id, :team_size, :team_participation,
        :rank, :tied_count,
        :forfeit_reason
    ]

    attr_accessible :_id, :ignored, *properties # _id is client-generated
    api_property *properties

    before_validation :denormalize

    def denormalize
        if match_length?
            self.match_participation_percent = match_participation.to_f / match_length.to_f if match_participation?
            self.team_participation_percent = team_participation.to_f / match_length.to_f if team_participation?
        end
    end

    def finished?
        !match_finished_at.nil?
    end

    def forfeit?
        !forfeit_reason.nil?
    end

    def win?
        rank == 0 && tied_count < competitor_count
    end

    def tie?
        rank == 0 && tied_count == competitor_count
    end

    def loss?
        rank != 0
    end

    def result_text
        if forfeit?
            "Forfeit"
        elsif win?
            "Win"
        elsif tie?
            "Tie"
        elsif loss?
            "Loss"
        end
    end

    def result_color
        if forfeit?
            "result-forfeit"
        elsif win?
            "result-win"
        elsif tie?
            "result-tie"
        elsif loss?
            "result-loss"
        end
    end
end
