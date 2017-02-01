class Group
    # Embedded document representing the user's membership in
    # a particular Group. A User has a set of these, each
    # with a unique group_id field. The start and stop fields are
    # the time window during which the membership is valid.
    # If either of these fields is nil, the window is unbounded in
    # the respective direction.
    class Membership
        include Mongoid::Document
        embedded_in :member, class_name: Member.name

        # Explicitly disable autosave, because Mongoid likes to enable it in
        # unexpected cases, e.g. if you have a presence validation on the field.
        belongs_to :group, :class_name => 'Group', autosave: false

        # Note that these fields MUST be set
        field :start, :type => Time
        field :stop, :type => Time

        field :staff_role, :type => String

        # [DEPRECATED] Determines the order of staff members
        field :seniority, :type => Float

        validates :group, reference: true, allow_nil: false, uniqueness: true
        validates :start, presence: true, allow_nil: false
        validates :stop,  presence: true, allow_nil: false

        before_validation do |m|
            m.start ||= Time.now
            m.stop ||= Time::INF_FUTURE
        end

        def active?(now = nil)
            now ||= Time.now
            self.start <= now && self.stop > now && group.alive?
        end

        def permanent?
            self.stop == Time::INF_FUTURE
        end

        alias_method :user, :_parent

        def username
            member.try(:username) || member.to_s
        end
    end
end
