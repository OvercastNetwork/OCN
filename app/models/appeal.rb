class Appeal
    include Mongoid::Document
    include Mongoid::Timestamps
    include BackgroundIndexes
    include ActionView::Helpers::DateHelper
    store_in :database => "oc_appeals"

    include Subscribable
    include Actionable
    include Closeable
    include Lockable
    include Escalatable

    class Alert < Subscription::Alert
        alias_method :appeal, :subscribable

        def link
            Rails.application.routes.url_helpers.appeal_latest_path(appeal)
        end

        def rich_message
            if appeal.punished == user
                [{message: "Your appeal has been updated by a staff member", time: true}]
            else
                [{user: appeal.punished, message: "'s appeal requires your attention", time: true}]
            end
        end
    end

    belongs_to :punished, class_name: 'User'
    alias_method :actionable_creator, :punished

    class Excuse
        include Mongoid::Document
        embedded_in :appeal

        belongs_to :punishment
        belongs_to :punisher, class_name: 'User', inverse_of: nil
        field :reason, type: String
    end
    embeds_many :excuses, class_name: 'Appeal::Excuse'

    def add_excuse(punishment, reason)
        excuses << Excuse.new(punishment: punishment, reason: reason)
    end

    # Some old appeals have no punishments, so only validate that on newly created ones
    validates_each :excuses, on: :create do |appeal, attr, value|
        if value.empty?
            appeal.errors.add(attr, "cannot be empty")
        end
    end

    field :authorized_ip

    index({authorized_ip: 1})
    index({updated_at: -1})
    index(INDEX_punished_updated_at = {punished_id: 1, updated_at: -1})
    index({'excuses.punisher_id' => 1})
    index({'excuses.punishment_id' => 1})

    scope :punished, -> (user) { where(punished_id: user.id) }
    scope :punisher, -> (*users) {
        if users.size == 1
            where('excuses.punisher_id' => users[0].id)
        else
            self.in('excuses.punisher_id' => users.map(&:id))
        end
    }
    scope :punishment, -> (p) { where('excuses.punishment_id' => p.id) }

    action Action::Appeal
    action Action::Unappeal
    action Action::Expire

    after_create :do_subscriptions
    after_create :do_auto_escalation

    before_create do
        # Denormalize punishers
        excuses.each do |excuse|
            excuse.punisher ||= excuse.punishment.punisher
        end
    end

    after_create do
        # Mark punishments appealed
        excuses.each do |excuse|
            excuse.punishment.appealed = true
            excuse.punishment.save!
        end
    end

    class << self
        def by_updated_at
            desc(:updated_at)
        end
    end

    def same_user?(user)
        user == self.punished
    end

    def status
        if locked?
            "Locked"
        elsif closed?
            "Closed"
        elsif escalated?
            "Escalated"
        elsif open?
            "Open"
        end
    end

    def color
        if locked?
            "danger"
        elsif closed?
            "success"
        elsif escalated?
            "warning"
        elsif open?
            "info"
        end
    end

    def do_subscriptions
        subscribe_user(punished) if punished.confirmed?

        all_punishers_subbed = true
        excuses.each do |excuse|
            all_punishers_subbed &&= excuse.punisher && subscribe_user(excuse.punisher)
        end

        alert_subscribers(except: punished)

        # If *any* of the punishers could not be subscribed (e.g. because they
        # no longer have permission to handle the appeal), then escalate
        # the appeal immediately.
        actions.create!({user: punished}, Action::Escalate) unless all_punishers_subbed
    end

    def do_auto_escalation
        if !escalated? && excuses.any? {|excuse| excuse.punishment.auto_escalated_type?}
            actions.create!({user: punished}, Action::Escalate)
        end
    end

    ###############
    # Permissions #
    ###############

    class << self
        # Filters
        #
        # These permission filters must be wraped in $and to prevent a later
        # chained query from expanding the result set. If these returned a
        # flat selector, a later query in the chain that filtered on the same
        # field would override it rather than intersect it. Similarly, if these
        # returned an $or selector, and another $or was chained after it,
        # Mongoid would collapse them into a single $or group, and the result
        # would be their union instead of their intersection. Note that the query
        # has to be isolated on BOTH ends to prevent interference.

        def actionable_by(user, action)
            q = all.isolate_selection
            q = if can_do?(user, 'all', action)
                    q.all
                elsif can_do?(user, 'involved', action)
                    q.any_of(punished(user).selector, punisher(user).selector)
                elsif can_do?(user, 'own', action)
                    q.punished(user)
                else
                    q.none
                end
            q.isolate_selection
        end

        def viewable_by(user)
            actionable_by(user, 'view')
        end

        def indexable_by(user)
            actionable_by(user, 'index')
        end

        def punished_viewable_by(punished, viewer = User.current)
            if can_view?('all', viewer) || (punished == viewer && can_view?('own', viewer))
                punished(punished).desc(:updated_at).hint(INDEX_punished_updated_at)
            else
                none
            end
        end

        # Global predicates

        def can_do?(user, scope, *nodes)
            user && (can_manage?(user) || user.has_permission?(permission_node, *nodes, 'all') || user.has_permission?(permission_node, *nodes, scope))
        end

        def can_view?(scope, user = nil)
            can_do?(user, scope, 'view')
        end

        def can_index?(scope, user = nil)
            can_do?(user, scope, 'index')
        end

        def can_sort?(sort, scope, user = nil)
            can_do?(user, scope, 'sort', sort)
        end
    end

    def owner?(user)
        user == punished
    end

    def involved?(user)
        owner?(user) || excuses.any?{|e| user == e.punisher }
    end

    def required_scope(user)
        if owner?(user)
            'own'
        elsif involved?(user)
            'involved'
        else
            'all'
        end
    end

    def can_do_in_any_state?(user, *nodes)
        self.class.can_do?(user, required_scope(user), *nodes)
    end

    def can_do_in_state?(user, state, *nodes)
        can_do_in_any_state?(user, "action_on_#{state}", *nodes)
    end

    def can_do_in_current_state?(user, *nodes)
        yes = true
        unless ['view', 'index'].include?(nodes[0])
            yes &= can_do_in_state?(user, 'closed', *nodes) if closed?
            yes &= can_do_in_state?(user, 'locked', *nodes) if locked?
            yes &= can_do_in_state?(user, 'escalated', *nodes) if escalated?
        end
        yes
    end

    def can_do?(user, *nodes)
        can_do_in_any_state?(user, *nodes) && can_do_in_current_state?(user, *nodes)
    end

    def can_view?(user = nil)
        can_do?(user, 'view')
    end

    def can_comment?(user = nil)
        can_do?(user, 'comment')
    end

    def can_close?(user = nil)
        can_do?(user, 'close') unless closed?
    end

    def can_open?(user = nil)
        can_do?(user, 'open') unless open?
    end

    def can_lock?(user = nil)
        can_do?(user, 'lock') unless locked?
    end

    def can_unlock?(user = nil)
        can_do?(user, 'unlock') unless unlocked?
    end

    def can_appeal?(user = nil)
        can_do_in_current_state?(user, 'appeal')
    end

    def can_unappeal?(user = nil)
        can_do_in_current_state?(user, 'unappeal')
    end

    def can_expire?(user = nil)
        can_do_in_current_state?(user, 'expire')
    end

    def can_view_ip?(user = nil)
        can_do_in_any_state?(user, 'view_ip')
    end

    def can_escalate?(user = nil)
        if escalated? || !can_do_in_current_state?(user, 'escalate')
            [false]
        elsif closed? || created_at < 2.days.ago || can_do_in_any_state?(user, 'escalate', 'immediately')
            [true, "This will delay response times."]
        elsif can_do_in_any_state?(user, 'escalate', 'delayed')
            [false, "You must wait #{time_ago_in_words(created_at - 48.hours)} to escalate this appeal."]
        else
            [false]
        end
    end
end
