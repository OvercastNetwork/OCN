module Subscribable
    extend ActiveSupport::Concern

    included do
        has_many :subscriptions, :as => :subscribable, :class_name => "Subscription"

        before_destroy do
            subscriptions.destroy_all
        end
    end

    def link
        # No link
    end

    # Return the subclass of Subscription::Alert to send for subscriptions
    # to this object
    Alert = Subscription::Alert
    def alert_class
        self.class::Alert
    end

    # Can the given user view this object? This will be checked before each
    # alert is sent to the subscriber.
    def can_view?(user)
        true
    end

    def subscribe_user(user)
        if can_view?(user)
            Rails.logger.info "Subscribing #{user.username} to #{self}"
            unless sub = subscriptions.user(user).one
                sub = Subscription.new(subscribable: self, user: user)
            end
            sub.unsubscribed = false
            sub.save!
            true
        end
    end

    def unsubscribe_user(user)
        subscriptions.user(user).cancel!
    end

    def unsubscribe_all
        subscriptions.cancel!
    end

    def subscriber?(user)
        subscriptions.active.user(user).exists?
    end

    def subscription_for(user)
        subscriptions.user(user).one
    end

    # Send an alert to all subscribers, excluding any given in :except:
    def alert_subscribers(except: nil, **opts)
        subscriptions.active.each do |sub|
            sub.alert_subscriber(except: except, **opts)
        end
    end

    def mark_read!(by: nil)
        q = subscriptions
        q = q.in(user: by.to_a) if by
        q.alerts.mark_read!
    end
end
