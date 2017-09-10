class Session
    include Mongoid::Document
    include BackgroundIndexes

    store_in :database => "oc_sessions"

    include ApiModel
    include User::Legacy::Macros

    field :start, type: Time
    field :end, type: Time
    field :ip
    field :version
    field :post_term, :type => Boolean # whether or not the session was ended improperly [WTF is this?]

    field :staff, type: Boolean

    field :family, type: String
    belongs_to :family_obj, class_name: 'Family', foreign_key: :family

    belongs_to :server

    belongs_to_legacy_user relation: :player,
                           external: :player_id,
                           internal: :user,
                           inverse_of: :sessions

    field :nickname, :type => String
    field :nickname_lower, :type => String

    validates_presence_of :family, :start, :user, :ip, :server

    api_property :server_id, :nickname, :nickname_lower, :ip, :start, :end, :version

    api_synthetic :family_id do
        family
    end

    api_synthetic :user do
        player.api_player_id
    end

    index({family: 1})
    index(INDEX_start = {start: 1})
    index(INDEX_end = {end: 1})
    index({server_id: 1})
    index({nickname_lower: 1})
    index(INDEX_ip_start = {ip: 1, start: -1})
    index(INDEX_version_start = {version: 1, start: -1})
    index(INDEX_user_start = {user: 1, start: -1})
    index(INDEX_user_ip_start = {user: 1, ip: 1, start: -1})
    index(INDEX_user_nickname_start = {user: 1, nickname_lower: 1, start: -1})
    index(INDEX_user_end_start = {user: 1, end: 1, start: -1})

    scope :network, -> (network) { self.in(server_id: Server.network(network).map(&:id)) }
    scope :families, -> (families) { where(family: {$in => families.map(&:id)}) }
    scope :user, -> (user) { where(user: user.player_id) }
    scope :users, -> (users) { where(:user.in => users.map(&:player_id)) }
    scope :staff, where(staff: true)
    scope :server, -> (server) { where(server: server) }
    scope :servers, -> (servers) { where(:server_id.in => servers.map(&:id)) }
    scope :undisguised, where(nickname_lower: nil)
    scope :online, where(end: nil).hint(INDEX_end)

    before_validation :denormalize_fields
    before_save :denormalize_fields

    def denormalize_fields
        if self.server
            self.family = self.server.family
            self.staff = self.player.is_mc_staff?(self.server.realms)
        end
    end

    def denormalize_nickname
        if self.player && self.player.nickname
            self.nickname ||= self.player.nickname
            self.nickname_lower = self.nickname.downcase
        end
    end

    def online?
        self.end.nil?
    end

    def interval(now: Time.now.utc)
        Time.at(self.start).getutc...if self.end.nil? then now else Time.at(self.end).getutc end
    end

    def duration
        self.end and self.end - self.start
    end

    class << self
        # Run the given User query, select Sessions for only those users,
        # and return them as an array, with Session#player populated from
        # the objects returned by the User query.
        def right_join_users(users)
            users = users.to_a
            users_by_player_id = users.index_by(&:player_id)

            sessions = users(users).to_a
            sessions.each do |session|
                session.set_relation(:player, users_by_player_id[session.user])
            end

            sessions
        end

        def left_join_users(users = User.all, sessions: all)
            sessions = sessions.to_a
            return sessions if sessions.empty?

            users = users.where(:player_id.in => sessions.map(&:user))
            users_by_player_id = users.index_by(&:player_id)

            sessions.each do |session|
                session.set_relation(:player, users_by_player_id[session.user])
            end

            sessions
        end

        def start!(server:, user:, ip:, version:, old_session: nil, now: Time.now.utc, **attrs)
            if old_session or old_session = last_online_started_by(user)
                # Finish old session without side-effects, because the new session will cause those effects.
                old_session.update(end: now, post_term: true)
                old_session.update_sightings!
            end

            new_session = new(start: now, server: server, player: user, ip: ip, version: version, **attrs)
            new_session.denormalize_nickname
            new_session.save!
            new_session.update_sightings!

            Publisher::TOPIC.publish_topic(SessionChange.new(old_session: old_session,
                                                             new_session: new_session))

            new_session
        end

        def finish_all!
            online.each(&:finish!)
        end

        def last_started_by(user)
            self.user(user).desc(:start).hint(INDEX_user_start).first
        end

        def last_public_started_by(user)
            self.user(user).undisguised.desc(:start).hint(INDEX_user_nickname_start).first
        end

        def last_online_started_by(user)
            self.user(user).online.desc(:start).hint(INDEX_user_end_start).first
        end
    end

    def update_sightings!
        player.update_sightings!(self) if player
    end

    def finish!
        unless end?
            self.end = Time.now.utc
            self.post_term = true
            save!
            update_sightings!

            Publisher::TOPIC.publish_topic(SessionChange.new(old_session: self))
        end
    end

    def disguised_to_anybody?
        nickname
    end

    def disguised_to?(viewer = User.current)
        nickname && !viewer.can_see_through_disguises? && !viewer.friend?(player)
    end
end
