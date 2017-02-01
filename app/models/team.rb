require_dependencies 'team/*'

class Team
    include Mongoid::Document
    include Mongoid::Timestamps
    include BackgroundIndexes
    store_in :database => "oc_teams"

    include Killable
    default_scope -> { alive }

    include ApiModel

    NAME_REGEX = /\A[a-zA-Z0-9_ ',.!?@#$%&():+=-]+\z/
    NAME_NORMALIZED_REGEX = /\A[a-z0-9]+\z/

    field :name, :type => String
    field :name_normalized, :type => String
    alias_method :to_param, :name_normalized

    # Previous (invalid) name before name cleanup
    field :legacy_name, :type => String
    field :legacy_name_problem, :type => String
    field :legacy_name_notified, :type => Boolean, :default => false

    field :mumble_token, type: String

    belongs_to :leader, class_name: 'User', inverse_of: nil
    has_many :alerts

    class Member
        include Mongoid::Document
        embedded_in :team

        belongs_to :user
        field :accepted, type: Boolean, default: false
        field :accepted_at, type: Time

        validates_presence_of :user

        def <=>(them)
            if [self.user, them.user].include?(self.team.leader)
                self.user == self.team.leader ? -1 : 1
            elsif self.accepted_at && them.accepted_at then
                self.accepted_at <=> them.accepted_at
            else
                self.accepted_at ? -1 : 1
            end
        end
    end

    # field :members, :type => Array, :default => Array.new
    embeds_many :members, store_as: 'members_2', class_name: 'Team::Member'
    field :member_count, :type => Integer, :default => 0

    # For legacy reasons, Entrant is embedded in Team rather than Tournament
    # This fact should be encapsulated as much as possible
    embeds_many :entrants, store_as: 'participations_2', class_name: 'Tournament::Entrant'

    index({name_normalized: 1})
    index({member_count: 1})
    index({created_at: 1})
    index({"#{relations['members'].key}.user_id" => 1})

    validates_format_of :name, with: NAME_REGEX
    validates_length_of :name, maximum: 32

    validates_format_of :name_normalized, with: NAME_NORMALIZED_REGEX
    validates_length_of :name_normalized, minimum: 2
    validates_uniqueness_of :name_normalized, among: alive
    validates_presence_of :leader

    validate do
        if alive? && self.leader && !self.is_member?(leader)
            errors.add(:leader, 'must be a member of the team')
        end

        if alive?
            members.empty? and errors.add(:members, "cannot be empty")
        else
            members.empty? or errors.add(:members, "must be empty for a deleted team")
        end
    end

    api_property :name, :name_normalized
    api_synthetic(:leader) { leader.api_player_id }
    api_synthetic(:members) { accepted_members.map{|m| m.user.api_player_id } }

    def api_identity_document
        api_document(only: [:_id, :name, :name_normalized])
    end

    after_initialize :normalize!
    before_validation :normalize!
    before_validation :ensure_leader_is_member
    before_save :normalize!
    before_save :update_member_count

    before_event :death do
        alert_members!(Alert::Disband, except: leader)
        true
    end

    class << self
        def clean_name(name)
            # collapse whitespace
            name.strip.gsub(/\s+/, ' ')
        end

        def normalize_name(name)
            # strip all but lowercase and digits
            name.downcase.gsub(/[^a-z0-9]/, '')
        end

        def by_name(name)
            find_by(name_normalized: normalize_name(name))
        end

        # Teams which the given user is a member of, or has been invited to
        def with_member(user, accepted = nil)
            q = where("#{relations['members'].key}.user_id" => user.id) # This will use the index
            q = q.elem_match(members: {user_id: user.id, accepted: accepted}) unless accepted.nil?
            q
        end

        def in_tournament(tournament)
            elem_match(entrants: {tournament_id: tournament.id})
        end
    end

    def normalize!
        self.name = Team.clean_name(self.name) if self.name
        self.name_normalized = Team.normalize_name(self.name) if self.name
    end

    def add_and_accept(user)
        self.members << Member.new(
            user: user,
            accepted: true,
            accepted_at: Time.now.utc
        )
    end

    def ensure_leader_is_member
        if alive? && leader && !is_member?(leader)
            add_and_accept(leader)
        end
    end

    def accepted_members
        self.members.select(&:accepted?)
    end

    def pending_members
        self.members.reject(&:accepted?)
    end

    def is_member?(user)
        self.members.where(user: user).exists?
    end

    def membership(user)
        self.members.find_by(user: user)
    end

    def is_accepted_member?(user = User.current)
        self.accepted_members.any?{|m| m.user == user }
    end

    def is_invited?(user)
        self.pending_members.any?{|m| m.user == user }
    end

    def alert_members!(alert_class, only: nil, except: nil, also: nil, **opts)
        [*accepted_members.map(&:user), *also].each do |user|
            if (only.nil? || [*only].include?(user)) && (except.nil? || ![*except].include?(user))
                alert_class.create!(team: self, user: user, **opts)
            end
        end
    end

    def invite!(user)
        self.members << Member.new(user: user)
        self.save!

        Alert::Invite.create!(team: self, user: user)
    end

    def force_add!(user)
        add_and_accept(user)
        save!
    end

    def mark_invitation!(user, decision)
        if decision
            if member = self.members.find_by(user: user)
                member.accepted = true
                member.accepted_at = Time.now.utc
                member.save!
            end
        else
            self.members.delete_if{|m| m.user == user}
        end

        self.save!

        if decision
            alert_members!(Alert::Join, member: user, except: user)
        else
            alert_members!(Alert::Decline, member: user, only: leader)
        end
    end

    def disband!
        members.destroy_all
        mark_dead
        save!
    end

    def remove_member!(user)
        members.where(user: user).destroy_all
        save!
    end

    def leave!(user)
        if user && user == leader
            disband!
        else
            remove_member!(user)
            alert_members!(Alert::Leave, member: user, except: user)
        end
    end

    def eject!(user)
        if user && user == leader
            disband!
        else
            was_accepted = is_accepted_member?(user)
            remove_member!(user)
            if was_accepted
                alert_members!(Alert::Leave, member: user, except: leader, also: user)
            else
                alerts.where(user: user).destroy_all
            end
        end
    end

    def change_leader!(user)
        unless user == leader
            self.leader = user
            self.save!

            alert_members!(Alert::ChangeLeader, member: user)
        end
    end

    # Is the given user currently participating in an active tournament with this team?
    def membership_locked?(user)
        self.entrants.any? do |p|
            p.tournament.unfinished? && p.members.where(user: user).exists?
        end
    end

    def participating_any?
        self.entrants.any?{|p| p.tournament.unfinished? }
    end

    def can_edit?(user = nil)
        alive? && user && (Tournament.can_manage?(user) || self.leader == user)
    end

    # Return a single string describing the most pertinent validation error
    def name_error
        invalid = short = long = taken = false
        errors.each do |field, error|
            if ['name', 'name_normalized'].include?(field.to_s)
                invalid ||= error =~ /invalid/
                short ||= error =~ /too short/
                long ||= error =~ /too long/
                taken ||= error =~ /taken/
            end
        end

        if taken
            :taken
        elsif invalid
            :invalid
        elsif short
            :short
        elsif long
            :long
        end
    end

    private
    def update_member_count
        self.member_count = self.accepted_members.count
    end
end
