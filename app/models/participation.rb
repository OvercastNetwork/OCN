class Participation
    include Mongoid::Document
    include BackgroundIndexes
    store_in :database => "oc_participations"

    include RequestCacheable
    include ApiModel
    include User::Legacy::Macros

    LEGACY_OBSERVING_TEAM_NAME = 'Observers'

    field :team, as: :team_name, type: String # PGM team name (legacy, not present on new documents)
    field :team_id, type: String # PGM team ID
    belongs_to :league_team, class_name: 'Team'

    field :start, type: Time
    field :end, type: Time
    scope :unfinished, -> { where(end: nil) }
    scope :participating, -> { ne(team: LEGACY_OBSERVING_TEAM_NAME) }

    belongs_to_legacy_user relation: :user,
                           external: :player_id,
                           internal: :player,
                           inverse_of: :participations
    field_scope :user

    field :family # Needed by the stats script
    belongs_to :match
    belongs_to :server
    belongs_to :session

    field_scope :match
    field_scope :server

    properties = [:start, :end,
                  :player_id, :team_id, :league_team_id,
                  :family, :match_id, :server_id, :session_id]

    attr_accessible :_id, *properties
    api_property *properties

    validates :team_id, :start, presence: true
    validates :league_team, reference: true, allow_nil: true
    validates :user, :match, :server, :session, reference: true

    index!({start: 1})
    index!({end: 1})
    index!({user: 1})
    index!({family: 1})
    index!({match: 1})
    index!({server: 1})
    index!({user: 1, start: -1})
    index!({user: 1, end: -1})

    def map
        match.map if match
    end

    attr_cached :match_team do
        if match
            if team_id
                match.competitors.find(team_id)
            elsif team_name
                match.competitors.find_by(name: team_name)
            end
        end
    end

    # Try to get a team name in various ways
    attr_cached :team_display_name do
        if league_team
            league_team.name
        elsif match_team
            match_team.name
        else
            team_name
        end
    end

    def observing?
        team == LEGACY_OBSERVING_TEAM_NAME
    end

    def participating?
        !observing?
    end

    def duration
        (self.end || Time.now) - self.start
    end

    class << self
        def finish(time = Time.now)
            self.unfinished.update_all(end: time)
        end

        def join_users_and_sessions(users: User.all, sessions: Session.all)
            partics = all.to_a

            users_by_pid = users.in(player_id: partics.map(&:player)).index_by(&:player_id)
            sessions_by_id = sessions.in(id: partics.map(&:session_id)).index_by(&:id)

            partics.each do |partic|
                user = users_by_pid[partic.player]
                session = sessions_by_id[partic.session_id]
                partic.set_relation(:user, user)
                if session
                    partic.set_relation(:session, session)
                    session.set_relation(:player, user)
                end
            end

            partics
        end
    end
end
