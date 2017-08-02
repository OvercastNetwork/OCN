class Punishment
    include Mongoid::Document
    include Mongoid::Timestamps::Updated
    include ActionView::Helpers::DateHelper
    include BackgroundIndexes
    include PunishmentHelper
    include ApiModel
    include ApiAnnounceable
    include ApiSearchable
    store_in :database => 'oc_punishments'

    STALE_REAL_TIME = 90.days
    STALE_PLAY_TIME = 40.hours
    FORUM_STALE_TIME = 1.year

    module Type
        WARN = 'WARN'
        KICK = 'KICK'
        BAN = 'BAN'
        FORUM_WARN = 'FORUM_WARN'
        FORUM_BAN = 'FORUM_BAN'
        TOURNEY_WARN = 'TOURNEY_WARN'
        TOURNEY_BAN = 'TOURNEY_BAN'
        ALL = [WARN, KICK, BAN, FORUM_WARN, FORUM_BAN, TOURNEY_BAN]
        GAME = [WARN, KICK, BAN]
        FORUM = [FORUM_WARN, FORUM_BAN]
        TOURNEY = [TOURNEY_BAN]
        EXPIRABLE = [BAN, FORUM_BAN, TOURNEY_BAN]
        AUTO_ESCALATED = [FORUM_WARN, FORUM_BAN]
        ANY_WARN = [WARN, FORUM_WARN, TOURNEY_WARN]
        ANY_BAN = [BAN, FORUM_BAN, TOURNEY_BAN]
    end

    # Fields

    belongs_to :punished, class_name: 'User'
    belongs_to :punisher, class_name: 'User'
    belongs_to :server
    belongs_to :match

    field :family, type: String, default: '_web'.freeze
    field :date, type: Time, default: Time.now
    field :reason, type: String
    field :evidence, type: String, default: nil

    field :type
    field :expire, type: Time, default: nil
    field :playing_time, as: :playing_time_ms, type: Integer

    # If this is true, the punishment is only meant for broadcast,
    # and should not be saved to the database.
    field :off_record, type: Boolean, default: false

    field :debatable, type: Boolean, default: true
    field :automatic, type: Boolean, default: false
    field :silent, type: Boolean, default: false
    field :active, type: Boolean, default: true
    field :appealed, type: Boolean, default: nil
    field :enforced, type: Boolean, default: false

    # Properties

    required = [
        # :punished, 
        :punished_id,
        :family, :date, :reason, :type,
        :debatable, :automatic, :active, :enforced
    ]

    props = [
        *required,
        :punisher, :punisher_id, :punished, :playing_time_ms,
        :server, :server_id, :match, :match_id,
        :evidence, :expire, :off_record, :silent
    ]

    attr_accessible :_id, *props
    api_property *props

    api_synthetic :punished do
        punished.api_player_id if punished
    end

    api_synthetic :punisher do
        punisher.api_player_id if punisher
    end

    api_synthetic :stale do
        stale?.to_bool
    end

    # Callbacks

    before_validation do
        playing_time_ms ||= punished.stats.playing_time_ms

        unless type
            self.type, duration = Punishment.calculate_next_game(punished)
            duration and self.expire = date + duration
        end
    end

    after_create do
        Punishment::Alert.create!(punishment: self)
    end

    # Validation

    validates_inclusion_of :type, in: Type::ALL
    validates_presence_of *required

    validates_each :off_record do |punishment, attr, value|
        if value
            punishment.errors.add attr, "must be false for persistent documents"
        end
    end

    # Indexes

    index({date: 1})
    index({family: 1})
    index({server_id: 1})
    index({match_id: 1})
    index(INDEX_punished_date = {punished_id: 1, date: -1})
    index(INDEX_punisher_date = {punisher_id: 1, date: -1})
    index({active: 1})
    index({appealed: 1})
    index({expire: 1})
    index({type: 1})

    # Scopes

    field_scope :punished
    field_scope :punisher
    field_scope :type

    scope :warns, type(Type::WARN)
    scope :kicks, type(Type::KICK)
    scope :bans, type(Type::BAN)
    scope :forum_warns, type(Type::FORUM_WARN)
    scope :forum_bans, type(Type::FORUM_BAN)
    scope :tourney_bans, type(Type::TOURNEY_BAN)

    scope :enforced, where(enforced: true)
    scope :unenforced, where(enforced: false)

    scope :active, where(active: true)
    scope :unappealed, ne(appealed: true)
    scope :unexpired, -> { any_of({expire: nil}, {:expire.gt => Time.now}) }

    scope :permanent_bans, -> { bans.where(expire: nil) }

    scope :appealable, -> { active.unappealed }
    scope :appealable_by, -> (user = User.current) { appealable.punished(user) }

    class << self

        # Punishment Status

        def banned?(user)
            active.unexpired.bans.punished(user).exists?
        end

        def permanently_banned?(user)
            active.unexpired.permanent_bans.punished(user).exists?
        end

        def forum_banned?(user)
            active.unexpired.forum_bans.punished(user).exists?
        end

        def tourney_banned?(user)
            active.unexpired.tourney_bans.punished(user).exists?
        end

        # Get the single currently effective ban for the given User, if any.
        # This will be the newest ban that is currently in effect.
        def current_ban(user)
            active.unexpired.bans.punished(user).desc(:date).first
        end

        # Punishment Track

        def track_count(user, types)
            Punishment.where(punished: user)
                      .in(type: types)
                      .count{|p| p.active? && !p.stale? }
        end

        def calculate_next_forum(user)
            case Punishment.track_count(user, Type::FORUM)
                when 0, 1
                    return Type::FORUM_WARN, nil
                when 2
                    return Type::FORUM_BAN, 7.days
                when 3
                    return Type::FORUM_BAN, 30.days
                else
                    return Type::FORUM_BAN, nil
            end
        end

        def calculate_next_game(user)
            case Punishment.track_count(user, [Type::KICK, Type::BAN])
                when 0
                    return Type::KICK, nil
                when 1
                    return Type::BAN, 7.days
                else
                    return Type::BAN, nil
            end
        end

        # Search

        def search_request_class
            PunishmentSearchRequest
        end

        def search_results(request: nil, documents: nil)
            documents = super

            if request
                if request.punisher
                    documents = documents.where(punisher_id: request.punisher).hint(INDEX_punisher_date)
                elsif request.punished
                    documents = documents.where(punished_id: request.punished).hint(INDEX_punished_date)
                    if request.active
                        documents = documents.where(active: request.active)
                    end
                end
            end

            documents
        end
    end

    # Alert

    class Alert < ::Alert
        include UserHelper
        belongs_to :punishment, index: true, validate: true

        attr_accessible :punishment

        def link
            user_path(punishment.punished)
        end

        def rich_message
            [{message: punishment.message}]
        end

        before_validation do
            self.user = punishment.punished
        end
    end

    def message
        "You were #{past_tense_verb} by a staff member!"
    end

    # Stale

    def stale?
        stale_from_real_time? # && stale_from_play_time?
    end

    def stale_from_real_time?
        case type
            when Type::KICK
                date + STALE_REAL_TIME < Time.now
            when Type::BAN
                expire && expire + STALE_REAL_TIME < Time.now
            when Type::FORUM_WARN
                date + FORUM_STALE_TIME < Time.now
            when Type::FORUM_BAN
                expire && expire + FORUM_STALE_TIME < Time.now
        end
    end

    def stale_from_play_time?
        !Type::GAME.include?(self.type) || (STALE_PLAY_TIME * 1000 < punished.stats.playing_time_ms - playing_time_ms)
    end

    # Punishment Types

    def title_description
        case type
            when Type::WARN
                "Warning"
            when Type::KICK
                "Kick"
            when Type::BAN
                expire? ? "Ban" : "Permanent Ban"
            when Type::FORUM_WARN
                "Forum Warning"
            when Type::FORUM_BAN
                "Forum Ban"
            when Type::TOURNEY_WARN
                "Tournament Warning"
            when Type::TOURNEY_BAN
                "Tournament Ban"
            else
                "Punishment"
        end
    end

    def description
        case type
            when Type::WARN
                "warning"
            when Type::KICK
                "kick"
            when Type::BAN
                expire? ? "ban" : "permanent ban"
            when Type::FORUM_WARN
                "forum warning"
            when Type::FORUM_BAN
                "forum ban"
            when Type::TOURNEY_WARN
                "tournament warning"
            when Type::TOURNEY_BAN
                "tournament ban"
            else
                "punishment"
        end
    end

    def reason_color
        case type
            when Type::WARN
                "green"
            when Type::KICK, Type::FORUM_WARN
                "orange"
            when Type::BAN, Type::FORUM_BAN, Type::TOURNEY_BAN
                "red"
            else
                "black"
        end
    end

    def past_tense_verb
        case type
            when Type::WARN
                "warned"
            when Type::KICK
                "kicked"
            when Type::BAN
                expire? ? "banned" : "permabanned"
            when Type::FORUM_WARN
                "forum warned"
            when Type::FORUM_BAN
                "forum banned"
            when Type::TOURNEY_WARN
                "tournament warned"
            when Type::TOURNEY_BAN
                "tournament banned"
            else
                "punished"
        end
    end

    def status_color(*allowed)
        allowed.flatten!
        unless allowed.nil? || allowed.empty?
            if allowed.include?('inactive') && !active?
                return 'success'
            elsif allowed.include?('stale') && stale?
                return 'danger'
            elsif allowed.include?('contested') && appealed?
                return 'info'
            elsif allowed.include?('automatic') && automatic?
                return 'warning'
            else
                return ''
            end
        end
        ''
    end

    def ban?
        Type::ANY_BAN.include?(type)
    end

    def kick?
        type == Type::KICK
    end

    def warn?
        Type::ANY_WARN.include?(type)
    end

    def auto_escalated_type?
        Type::AUTO_ESCALATED.include?(type)
    end

    def expirable_type?
        Type::EXPIRABLE.include?(type)
    end

    def expirable?
        active? && expirable_type? && (expire.nil? || expire.future?)
    end

    # Misc

    def appeals
        Appeal.punishment(self).to_a
    end

    def match_full
        if self.match.nil?
            if self.server?
                self.match = Match.where(:server => self.server, :start.lte => self.date, :end.gte => self.date).first
                self.save
            end
        end

        self.match
    end

    def punisher_name
        if punisher
            punisher.username
        else
            "*Console"
        end
    end

    # Only used for IP bans right now
    def mc_kick_message(reason: nil, expire: nil, appeal: true)
        msg = ChatColor::RED

        if expire
            msg += "Banned (expires #{expire})"
        else
            msg += "Permanently Banned"
        end

        msg += ChatColor::AQUA + "\n\n \u00bb #{reason}" if reason

        if appeal
            msg += ChatColor::YELLOW + "\n\nIf this is a mistake, visit " + ChatColor::GOLD + appeal_path
        else
            msg += ChatColor::YELLOW + "\n\nIf this is a mistake, email your IP to " + ChatColor::GOLD + ORG::EMAIL
        end

        msg
    end

    # Permissions

    def self.can_manage?(user = nil)
        return user && (user.admin? || user.has_permission?('punishment', 'manage', true))
    end

    def self.can_issue?(type, user = nil)
        return user && (Punishment.can_manage?(user) || user.has_permission?('punishment', 'create', type.downcase, true))
    end

    def self.can_issue_forum?(user = nil)
        Type::FORUM.any?{|type| Punishment.can_issue?(type, user)}
    end

    def self.can_issue_any?(user = nil)
        Type::ALL.any?{|type| Punishment.can_issue?(type, user)}
    end

    def can_view?(user = nil)
        user ||= User.anonymous_user
        if Punishment.can_manage?(user)
            return true
        else
            scope = user == self.punished ? 'own' : 'all'
            visible = user.has_permission?('punishment', 'view', 'type', self.type.downcase, scope) || (scope == 'own' && user.has_permission?('punishment', 'view', 'type', self.type.downcase, 'all'))
            visible = visible && (user.has_permission?('punishment', 'view', 'status', 'stale', scope) || (scope == 'own' && user.has_permission?('punishment', 'view', 'status', 'stale', 'all'))) if self.stale?
            visible = visible && (user.has_permission?('punishment', 'view', 'status', 'inactive', scope) || (scope == 'own' && user.has_permission?('punishment', 'view', 'status', 'inactive', 'all'))) if !self.active?
            visible = visible && (user.has_permission?('punishment', 'view', 'status', 'automatic', scope) || (scope == 'own' && user.has_permission?('punishment', 'view', 'status', 'automatic', 'all'))) if self.automatic?
            visible = visible && (user.has_permission?('punishment', 'view', 'status', 'contested', scope) || (scope == 'own' && user.has_permission?('punishment', 'view', 'status', 'contested', 'all'))) if self.appealed?
            return visible
        end
    end

    def can_view_evidence?(user = nil)
        user ||= User.anonymous_user
        self.can_view?(user) && (Punishment.can_manage?(user) || user == self.punished)
    end

    def self.can_index?(criteria, scope, user = nil)
        user ||= User.anonymous_user
        Punishment.can_manage?(user) ||
            user.has_permission?('punishment', 'index', *criteria, scope) ||
            (scope == 'own' && user.has_permission?('punishment', 'index', *criteria, 'all'))
    end

    def can_index?(user = nil)
        scope = user == self.punished ? 'own' : 'all'
        visible = Punishment.can_index?(['type', self.type.downcase], scope, user)
        visible = visible && Punishment.can_index?(%w(status stale), scope, user) if self.stale?
        visible = visible && Punishment.can_index?(%w(status inactive), scope, user) if !self.active?
        visible = visible && Punishment.can_index?(%w(status automatic), scope, user) if self.automatic?
        visible = visible && Punishment.can_index?(%w(status contested), scope, user) if self.appealed?
        visible
    end

    def self.can_sort?(sort, scope, user = nil)
        user ||= User.anonymous_user
        Punishment.can_manage?(user) ||
            user.has_permission?('punishment', 'sort', sort, scope) ||
            (scope == 'own' && user.has_permission?('punishment', 'sort', sort, 'all'))
    end

    def self.can_distinguish_status?(status, scope, user = nil)
        user ||= User.anonymous_user
        Punishment.can_manage?(user) ||
            user.has_permission?('punishment', 'distinguish_status', status, scope) ||
            (scope == 'own' && user.has_permission?('punishment', 'distinguish_status', status, 'all'))
    end

    def can_distinguish_status?(status, user = nil)
        Punishment.can_distinguish_status?(status, user == self.punished ? 'own' : 'all', user)
    end

    def self.can_edit?(field, scope, user = nil)
        return user && (Punishment.can_manage?(user) || user.has_permission?('punishment', 'edit', field.to_s, scope) || (scope == 'own' && user.has_permission?('punishment', 'edit', field.to_s, 'all')))
    end

    def can_edit?(field, user = nil)
        Punishment.can_edit?(field, user == self.punisher ? 'own' : 'all', user)
    end

    def self.can_edit_any?(scope, user = nil)
        Punishment.accessible_attributes.any? {|field| true if Punishment.can_edit?(field, scope, user)} if user
    end

    def can_edit_any?(user = nil)
        Punishment.can_edit_any?(user == self.punisher ? 'own' : 'all', user)
    end

    def self.can_delete?(scope, user = nil)
        return user && (Punishment.can_manage?(user) || user.has_permission?('punishment', 'delete', scope) || (scope == 'own' && user.has_permission?('punishment', 'delete', 'all')))
    end

    def can_delete?(user = nil)
        Punishment.can_delete?(user == self.punisher ? 'own' : 'all', user)
    end

end
