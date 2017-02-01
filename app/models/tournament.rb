class Tournament
    include Mongoid::Document
    include Mongoid::Timestamps
    include ApiModel
    include ApiSyncable

    store_in :database => 'oc_tournaments'

    class Entrant
        include Mongoid::Document
        include ApiModel

        embedded_in :team

        belongs_to :tournament
        field :registered_at, type: Time

        validates_presence_of :tournament, :registered_at

        class Member
            include Mongoid::Document
            embedded_in :entrant, class_name: 'Tournament::Entrant'

            belongs_to :user
            field :confirmed, type: Boolean, default: false

            validates_presence_of :user

            def confirm!
                self.confirmed = true
                self.save!

                entrant.team.alert_members!(Team::Alert::Confirm,
                                            tournament: entrant.tournament,
                                            member: user,
                                            only: entrant.team.leader)

                true
            end
        end
        embeds_many :members, class_name: 'Tournament::Entrant::Member'

        # Note: 'matches' is an invalid field name due to conflict with a base method called 'matches?'
        has_and_belongs_to_many :official_matches, class_name: 'Match', inverse_of: nil

        api_property :team

        api_synthetic :members do
            confirmed_members.map{|m| m.user.api_player_id }
        end

        api_synthetic :matches, :official_matches

        def accepted?
            tournament.team_accepted?(team)
        end

        def confirmed?
            members.all?(&:confirmed?)
        end

        def confirmed_members
            members.select(&:confirmed?)
        end

        def users
            members.map(&:user)
        end

        def confirmed_users
            confirmed_members.map(&:user)
        end

        def member_for(user)
            members.find_by(user: user)
        end

        def user_registered?(user)
            !member_for(user).nil?
        end

        def user_confirmed?(user)
            m = member_for(user) and m.confirmed?
        end

        def user_unconfirmed?(user)
            m = member_for(user) and !m.confirmed?
        end
    end

    field :name, :type => String
    field :url, :type => String

    field :active, :type => Boolean, :default => false
    scope :active, where(active: true)

    field :can_register_teams, :type => Boolean, :default => true

    field :end, :type => Time

    field :registration_start, :type => Time
    field :registration_end, :type => Time

    scope :registration_open, -> {
        now = Time.now
        active.where(can_register_teams: true).lte(registration_start: now).gte(registration_end: now)
    }

    field :details, :type => String

    field :max_players_per_team, :type => Integer
    field :min_players_per_team, :type => Integer

    field :max_players_per_match, :type => Integer, :default => 10
    field :min_players_per_match, :type => Integer, :default => 8

    field :hide_teams, :type => Boolean, :default => false

    # TODO: make this a real relation
    field :accepted_teams, as: :accepted_team_ids, :type => Array, :default => [].freeze

    def accepted_teams
        Team.in(id: accepted_team_ids)
    end

    attr_accessible :name, :url, :active, :can_register_teams, :end, :registration_start, :registration_end,
                    :details, :max_players_per_team, :min_players_per_team, :max_players_per_match, :min_players_per_match

    validates_presence_of :name
    validates_format_of :url, with: /\A[a-z0-9-]+\z/
    validates_uniqueness_of :url
    validates_presence_of :end
    validates_presence_of :registration_start
    validates_presence_of :registration_end
    validates_presence_of :max_players_per_team
    validates_presence_of :min_players_per_team
    validates_presence_of :max_players_per_match
    validates_presence_of :min_players_per_match

    before_save do
        [:end, :registration_start, :registration_end].each do |field|
            self[field] = self[field].utc
        end
    end

    # Unused legacy fields

    field :can_edit_teams, :type => Boolean, :default => true
    field :start, :type => Time
    field :information
    field :hide_text, :type => Boolean, :default => false
    # Example:
    # {
    #     'wool' => ['Race for Victory 2', 'Golden Drought'],
    #     'core' => ['War Wars', 'Avalanche'],
    #     'tdm' => ['BlockBlock']
    # }
    field :map_classifications, :type => Hash, :default => {}.freeze

    api_property :name, :start, :end, :min_players_per_match, :max_players_per_match

    api_synthetic :accepted_teams do
        accepted_teams.map(&:api_identity_document)
    end

    api_synthetic :map_classifications do
        map_classifications.map do |name, map_ids|
            {
                name: name,
                map_ids: map_ids
            }
        end
    end

    # End legacy fields

    def can_register?
        return false if Time.now < self.registration_start
        return false if Time.now > self.registration_end
        self.can_register_teams?
    end

    def finished?
        Time.now >= self.end
    end

    def unfinished?
        Time.now < self.end
    end

    def entrants
        registered_teams.map{|team| entrant_for(team) }
    end

    def accepted_entrants
        accepted_teams.map{|team| entrant_for(team) }
    end

    def entrant_for(team)
        team.entrants.find_by(tournament: self)
    end

    def registered_teams
        Team.in_tournament(self)
    end

    def confirmed_teams
        registered_teams.select{|team| team_confirmed?(team) }
    end

    def team_registered?(team)
        team.entrants.where(tournament: self).exists?
    end

    def team_confirmed?(team)
        entrant_for(team).try!(:confirmed?)
    end

    def team_accepted?(team)
        accepted_team_ids.include?(team.id)
    end

    def register_team!(team, users)
        members = [team.leader, *users].uniq.map do |u|
            Entrant::Member.new(user: u, confirmed: u == team.leader)
        end

        team.entrants << Entrant.new(
            tournament: self,
            registered_at: Time.now.utc,
            members: members
        )

        team.save!

        team.alert_members!(Team::Alert::Register, tournament: self, only: users)
    end

    def unregister_team!(team)
        accepted_team_ids.delete(team.id)

        team.entrants.where(tournament: self).destroy_all
        team.save!

        team.alert_members!(Team::Alert::Unregister, tournament: self)
    end

    def accept_team!(team)
        unless team_accepted?(team)
            accepted_team_ids << team.id
            team.alert_members!(Team::Alert::Accept, tournament: self)
        end
    end

    def decline_team!(team)
        if team_accepted?(team)
            accepted_team_ids.delete(team.id)
            team.alert_members!(Team::Alert::Reject, tournament: self)
        end
    end

    def img
        'tournaments/' + url.gsub('-', '_') + '.png'
    end

    def self.can_manage?(user = User.current)
        return user && (user.admin? || user.has_permission?('tournament', 'manage', true))
    end

    def self.can_participate?(user = nil)
        return user && !user.is_tourney_banned? && (Tournament.can_manage?(user) || user.has_permission?('tournament', 'participate', true))
    end

    def self.can_accept?(user = nil)
        return user && (Tournament.can_manage?(user) || user.has_permission?('tournament', 'accept', true))
    end

    def self.can_decline?(user = nil)
        return user && (Tournament.can_manage?(user) || user.has_permission?('tournament', 'decline', true))
    end

    def record_match(match)
        match.competitors.map(&:league_team).compact.map do |team|
            if entrant = entrant_for(team) and !entrant.official_matches.include?(match)
                entrant.official_matches << match
                entrant.save!
                entrant
            end
        end.compact
    end
end
