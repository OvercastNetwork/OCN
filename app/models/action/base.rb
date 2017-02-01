module Action
    class Base
        include Mongoid::Document
        include Mongoid::Timestamps
        include BackgroundIndexes
        include DisablePolymorphism

        store_in :database => "oc_actions", :collection => "actions"

        field :type, type: String, default: -> { self.class.token }

        # field :user
        belongs_to :user, index: true
        field_scope :user
        belongs_to :actionable, polymorphic: true

        # all actions can have a comment
        field :comment, type: String

        validates_presence_of :type
        validates_inclusion_of :type, in: -> (_) { Base.actions_by_token.keys }
        validates_presence_of :user_id
        validates_presence_of :actionable_id
        validates_presence_of :actionable_type

        validate do |action|
            if action.actionable && !action.actionable.valid_action?(action)
                action.errors.add(:base, "Invalid action #{action} on #{action.actionable}")
            end
        end

        attr_accessible :user, :actionable, :comment

        index({created_at: 1})
        index({type: 1, created_at: 1})
        index({actionable_id: 1, created_at: 1})
        index({actionable_type: 1})

        before_create do
            actionable.before_action_add(self)
        end

        after_create do
            actionable.after_action_add(self)
        end

        def rich_description
            [{user: user, message: " performed an unknown action"}]
        end

        class << self
            def token(t = nil)
                actions_by_token[@token = t.to_s] = self if t
                @token
            end

            def actions_by_token
                if self == Base
                    @actions_by_token ||= {}
                else
                    Base.actions_by_token
                end
            end

            def action_for_token(t)
                actions_by_token[t.to_s]
            end

            def instantiate(attrs = nil, *args)
                token = attrs['type']
                if self == Base && token && klass = action_for_token(token)
                    klass.instantiate(attrs, *args)
                else
                    super
                end
            end

            def queryable
                if token
                    super.where(type: token)
                else
                    super
                end
            end
        end

        delegate :token, to: self
    end
end
