class Subscription
    include Mongoid::Document
    include Mongoid::Timestamps
    include BackgroundIndexes
    store_in :database => "oc_forem_subscriptions", :collection => "forem_subscriptions"

    field :unsubscribed, :type => Boolean, :default => false
    scope :active, ne(unsubscribed: true)
    def active?
        !unsubscribed?
    end

    belongs_to :subscribable, polymorphic: true, index: true

    belongs_to :user, index: true
    field_scope :user

    class Alert < ::Alert
        belongs_to :subscription, index: true, validate: true
        field :subscription_type, type: String

        validates_presence_of :subscription
        validates_presence_of :subscription_type

        attr_accessible :subscription

        delegate :link, :subscribable, to: :subscription

        before_validation do
            if subscription
                self.user = subscription.user
                self.subscription_type = subscription.subscribable_type
            end
        end

        # Combine a newer alert for the same subscription into this one.
        # Return true if the new alert should be kept, false to discard it.
        # The base implementation destroys self and returns true.
        def combine(newer)
            destroy
            true
        end
    end
    has_many :alerts, class_name: 'Subscription::Alert'

    attr_accessible :subscribable, :user

    before_destroy do
        alerts.destroy_all
    end

    validates_presence_of :user
    validates_presence_of :subscribable

    index({unsubscribed: 1})
    index({updated_at: -1})
    index({user_id: 1, subscribable_type: 1, unsubscribed: 1, updated_at: -1}) # For "My Subscriptions"

    # Pass the class of the subscribable
    scope :subscribable_type, -> (type) { where(subscribable_type: type.name) }

    class << self
        def alerts
            Alert.in(subscription: all.to_a)
        end

        def cancel!
            active.update_all(unsubscribed: true)
        end
    end

    delegate :link, :alert_class, to: :subscribable

    # Send an alert for this subscription, if it is active, and the subscriber is
    # allowed to view the subscribable object, and the subscriber is not passed
    # in the :except: argument.
    def alert_subscriber(except: nil, **opts)
        if active? && ![*except].include?(user) && subscribable.can_view?(user)
            older = alerts.unread.desc(:updated_at).first
            newer = alert_class.new(subscription: self, **opts)
            newer.save! if older.nil? || older.combine(newer)
        end
    end
end
