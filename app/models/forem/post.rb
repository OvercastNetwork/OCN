module Forem
    class Post
        include Mongoid::Document
        include Mongoid::Timestamps
        include BackgroundIndexes
        include Workflow
        include ::FormattingHelper
        include UserHelper
        include Async

        store_in :database => "oc_forem_posts"

        class Alert < ::Alert
            include PostsHelper

            belongs_to :forem_post_quoter, class_name: 'User'
            belongs_to :forem_post_quote, class_name: 'Forem::Post'

            attr_accessible :forem_post_quoter, :forem_post_quote

            validates_presence_of :forem_post_quoter
            validates_presence_of :forem_post_quote

            def link
                post_path(forem_post_quote)
            end

            def rich_message
                [{user: forem_post_quoter, message: " quoted you in a post", time: true}]
            end
        end

        CREATE_COOLDOWN = 3.minutes

        MODERATION_ACTIONS = [:hide, :approve]

        MAX_LENGTH = 30000

        field :state, type: String, validates: {presence: true}, default: -> { :approved }
        field_scope :state
        scope :approved, -> { state(:approved) }
        scope :visible, -> { ne(state: :hidden) }

        field :text, type: String, validates: {presence: true}

        field :notified, type: Boolean
        field :converted, type: Boolean
        field :pinned, type: Boolean
        field_scope :pinned

        workflow_column :state
        workflow do
            state :approved do
                event :hide, :transitions_to => :hidden
            end
            state :hidden do
                event :approve, :transitions_to => :approved
            end
        end

        attr_accessor :moderation_option
        attr_accessible :text, :reply_to_id, :topic, :converted,
                        as: :creator
        attr_accessible :text, :converted,
                        as: :editor

        # Path of a file to append to the post.
        #
        # This is for internal use only. Normal users cannot access it,
        # and it would be dangerous to let them since the content is not sanitized.
        #
        # If the path ends in ".markdown" then it will be rendered as such,
        # otherwise it is rendered verbatim.
        #
        # Attachments are wrapped in a <div> with the class "attachment-<filename>",
        # where <filename> is the name of the file alone, without an extension.
        field :attachment_path

        belongs_to :topic, class_name: 'Forem::Topic', validates: {reference: true}
        field_scope :topic
        belongs_to :user, validates: {reference: true}
        field_scope :user
        belongs_to :reply_to, class_name: 'Forem::Post', validates: {reference: true, allow_nil: true}

        # Denormalization
        field :first_post, type: Boolean

        validates_each(:reply_to, allow_nil: true) do |reply, attr, orig|
            unless reply.topic == orig.topic
                reply.errors.add(attr, "is in a different topic")
            end
        end

        validate :enforce_cooldown
        validate :enforce_max_length

        delegate :forum, to: :topic

        # For "My Posts"
        index(INDEX_user_state_created_desc = {user_id: 1, state: 1, created_at: -1, _id: -1})
        scope :latest_by, -> (user) { user(user).desc(:created_at, :_id).hint(INDEX_user_state_created_desc) }

        # To find latest post
        index(INDEX_topic_state_created_desc = {topic_id: 1, state: 1, created_at: -1, _id: -1})
        scope :latest_for_topic, -> (topic) { topic(topic).visible.desc(:created_at, :_id).hint(INDEX_topic_state_created_desc) }

        # View topic
        index(INDEX_topic_created = {topic_id: 1, created_at: 1, _id: 1})
        scope :for_topic, -> (topic) { topic(topic).asc(:created_at, :_id).hint(INDEX_topic_created)}

        # To find pinned posts for topic view
        index(INDEX_topic_pinned_created = {topic_id: 1, pinned: -1, created_at: 1, _id: 1})
        scope :pinned_for_topic, -> (topic) { topic(topic).pinned(true).asc(:created_at, :_id) }

        index({created_at: 1})
        index({updated_at: 1})
        index({topic_id: 1})
        index({user_id: 1})
        index({state: 1, created_at: -1})
        index({topic_id: 1, _id: 1})

        before_validation do
            self.user ||= User.current
            self.pinned = self.pinned? ? true : nil
            self.text = normalize_user_urls(text) if text
        end

        after_save :subscribe_replier, :if => Proc.new { |p| p.user && p.user.forem_auto_subscribe? }

        after_event_async :create, :notify_parents_create
        after_event_async :update, :notify_parents_update
        after_event_async :create, :send_alerts, unless: :first_post?

        def notify_parents_create
            topic.atomically do
                topic.mark_visibly_updated!(created_at)
                topic.denormalize_posts!
            end
            topic.forum.increment_posts_count!
        end

        def notify_parents_update
            topic.atomically do
                topic.denormalize_posts!
            end
        end

        def send_alerts
            quoted = reply_to && reply_to.user

            if quoted && quoted != user && quoted.quote_notification?
                Forem::Post::Alert.create!(
                    user: quoted,
                    forem_post_quote: self,
                    forem_post_quoter: user
                )
            end

            topic.alert_subscribers(
                except: [user, *quoted],
                forem_topic_post: self,
                forem_topic_replier: user
            )
        end

        class << self
            def approved_or_pending_review_for(user)
                if user
                    Post.all_of("$or" => [{:state => :approved}, {"$and" => [{:state => :pending_review}, {:user_id => user.id}]}])
                else
                    approved
                end
            end

            def topic_order
                order_by(pinned: :desc, created_at: :asc)
            end

            def by_created_at
                order_by([:created_at, :asc])
            end

            def by_reverse_created_at
                order_by([:created_at, :desc])
            end

            def by_updated_at
                order_by([:updated_at, :desc])
            end

            def moderate!(posts, action)
                posts.each do |post|
                    post.send("#{action}!") if post.current_state.events.include?(action.to_sym)
                end
            end
        end

        def enforce_cooldown
            unless persisted?
                user = self.user || User.current
                unless user.has_permission?(:forum, forum.id.to_s, :bypass_cooldown, true)
                    last_post = self.class.latest_by(user).first
                    if last_post && last_post.created_at + CREATE_COOLDOWN > Time.now
                        errors.add(:base, "Upgrade to premium to avoid the #{time_ago_shorthand(last_post.created_at + CREATE_COOLDOWN)} post cooldown")
                    end
                end
            end
        end

        def enforce_max_length
            if self.text.length > MAX_LENGTH
                errors.add(:base, "Character limit exceeded! Please reduce the length of your post.")
            end
        end

        def approved?
            state.to_sym == :approved
        end

        def pinned=(value)
            if value
                super(true)
            else
                super(nil)
            end
        end

        def convert
            self.text = ReverseMarkdown.convert self.text
            self.text = self.text.gsub("\u00A0", ' ').strip
            self.converted = true
        end


        # Permissions

        class << self
            def can_do?(action:, forum:, ownership:, state: nil, user: User.current)
                forum.can_manage?(user) || (
                user.has_permission?(:forum, forum, :post, :"#{action}_parent", ownership) &&
                    (state.nil? || user.has_permission?(:forum, forum, :post, action, :status, state, ownership))
                )
            end
        end

        def ownership(user = User.current)
            if user == self.user
                :own
            else
                :all
            end
        end

        def can_do?(action:, user: User.current)
            self.class.can_do?(action: action, forum: forum, ownership: ownership(user), state: (:hidden if hidden?), user: user)
        end

        def can_view?(user = User.current)
            can_do?(action: :view, user: user)
        end

        # TODO: Does nothing right now
        def can_quote?(user = User.current)
            !first_post? && topic.can_reply?(user) && can_do?(action: :quote, user: user)
        end

        def can_hide?(user = User.current)
            return false if first_post? || hidden?
            if self.forum.can_manage?(user)
                return true
            end
            scope = user == self.user ? 'own' : 'all'
            visible = user.has_permission?('forum', self.forum.id.to_s, 'post', 'hide', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'post', 'hide', 'all'))
            visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.topic.hidden?
            visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.topic.locked?
            visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.topic.archived?
            visible
        end

        def can_approve?(user = User.current)
            return false if first_post? || !hidden?
            if self.forum.can_manage?(user)
                return true
            end
            scope = user == self.user ? 'own' : 'all'
            visible = user.has_permission?('forum', self.forum.id.to_s, 'post', 'approve', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'post', 'approve', 'all'))
            visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.topic.hidden?
            visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.topic.locked?
            visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.topic.archived?
            visible
        end

        def can_edit?(user = User.current)
            if self.forum.can_manage?(user)
                return true
            end
            scope = user == self.user ? 'own' : 'all'
            visible = user.has_permission?('forum', self.forum.id.to_s, 'post', 'edit_parent', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'post', 'edit_parent', 'all'))
            visible = visible && user.has_permission?('forum', self.forum.id.to_s, 'post', 'edit', 'status', 'hidden', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'post', 'edit', 'status', 'hidden', 'all')) if self.state == 'hidden'
            visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.topic.hidden?
            visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.topic.locked?
            visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.topic.archived?
            visible
        end

        def can_pin?(user = User.current)
            if self.forum.can_manage?(user)
                return true
            end
            scope = user == self.user ? 'own' : 'all'
            visible = user.has_permission?('forum', self.forum.id.to_s, 'post', 'pin', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'post', 'pin', 'all'))
            visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.topic.hidden?
            visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.topic.locked?
            visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.topic.archived?
            visible
        end

        def can_moderate?(user = User.current)
            MODERATION_ACTIONS.any?{|action| __send__("can_#{action}?", user) }
        end

        protected
        def subscribe_replier
            if self.topic && self.user
                self.topic.subscribe_user(self.user)
            end
        end

        def delete!
            delete
        end
    end
end
