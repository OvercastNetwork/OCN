module Actionable
    extend ActiveSupport::Concern
    include Mongoid::Document

    include Protectable
    include Subscribable

    included do
        has_many :actions,
                 class_name: 'Action::Base',
                 as: :actionable,
                 order: {created_at: 1}

        belongs_to :last_action, class_name: 'Action::Base'

        action Action::Create

        action Action::Comment do
            self.open = true if is_a?(Closeable) && is_a?(Escalatable) && escalated?
        end

        after_create do
            if generate_create_action?
                actions.create!({user: actionable_creator}, Action::Create)
            end
        end

        before_save do
            unless last_action?
                self.last_action = actions.desc(:created_at).first
            end
        end
    end

    module ClassMethods
        # Return the list of valid action types on this Actionable.
        # Action objects will validate that their type is in this list.
        # Subclasses can override to add their own actions.
        def defined_actions
            @defined_actions ||= {}
        end

        # Declare the given Action::Base subclass to be a valid action on
        # this Actionable.
        #
        # If a block is given, it will the first thing that runs in response
        # to the action, and the object will be saved after it returns.
        # The block should only update the state of the object. Secondary
        # concerns should use :after_action: callbacks.
        def action(klass, &block)
            defined_actions[klass] = {block: block, callbacks: []}
        end

        def valid_action?(action)
            if action.is_a? Class
                defined_actions.include? action
            else
                defined_actions.include? action.class
            end
        end

        def assert_valid_action(action)
            raise TypeError, "Invalid action #{action} on #{self}" unless valid_action?(action)
        end

        # Define a block to run after the given action happens
        def after_action(klass, &block)
            assert_valid_action(klass)
            defined_actions[klass][:callbacks] << block
        end
    end

    delegate :defined_actions, :valid_action?, :assert_valid_action, to: 'self.class'

    # Return the User that created this object (subclasses must implement this)
    def actionable_creator
        raise NotImplementedError
    end

    def description
        self.class.name.downcase
    end

    # Should a Create action be added automatically?
    def generate_create_action?
        true
    end

    def before_action_add(action)
        assert_valid_action(action)
        raise Permissions::Denied unless can_act?(action)
    end

    def after_action_add(action)
        action_info = defined_actions[action.class]
        if block = action_info[:block]
            instance_eval(&block)
        end

        # Update timestamps on the Actionable
        touch
        self.last_action = action
        save!

        # Subscribe the actor to this object
        subscribe_user(action.user)

        # Mark the actor's alerts for this object as read
        mark_read!(by: action.user)

        # Alert other subscribers
        alert_subscribers(except: action.user)

        action_info[:callbacks].each do |callback|
            instance_eval(&callback)
        end

        action
    end

    def can_act?(action)
        method = "can_#{action.token}?"
        !respond_to?(method) || __send__(method, action.user)
    end
end
