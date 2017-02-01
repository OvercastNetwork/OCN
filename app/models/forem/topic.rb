require_dependency 'forem/forum'
require_dependency 'forem/post'

module Forem
    class Topic
        include Mongoid::Document
        include Mongoid::Timestamps
        include ::FormattingHelper
        store_in :database => "oc_forem_topics"

        include Subscribable
        include Viewable

        class Alert < Subscription::Alert
            include PostsHelper

            belongs_to :forem_topic_replier, class_name: 'User'
            belongs_to :forem_topic_post, class_name: 'Forem::Post'
            field :forem_topic_count, type: Integer, default: 0

            attr_accessible :forem_topic_replier, :forem_topic_post, :forem_topic_count

            validates_presence_of :forem_topic_replier
            validates_presence_of :forem_topic_post

            alias_method :topic, :subscribable

            def link
                if forem_topic_post
                    post_path(forem_topic_post)
                else
                    Engine.url_helpers.topic_path(topic.id)
                end
            end

            def rich_message
                message = ''
                message << " and #{forem_topic_count} #{"other".pluralize(forem_topic_count)}" if forem_topic_count > 0
                message << " replied to #{topic.subject}"
                [{user: forem_topic_replier, message: message, time: true}]
            end

            def combine(newer)
                # Bump the post count on the old alert instead of making a new one
                where_self.update($set => {updated_at: Time.now}, $inc => {forem_topic_count: 1})
                false
            end
        end

        # Minimum time between topic creation per user
        CREATE_COOLDOWN = 5.minutes

        MODERATION_ACTIONS = [:hide, :approve, :lock, :unlock, :pin, :unpin, :edit_title, :move]

        field :subject, type: String, validates: {presence: true, length: {minimum: 2, maximum: 128}}
        field :locked, type: Boolean, default: false
        field :pinned, type: Boolean, default: false
        field :hidden, type: Boolean, default: false
        field_scope :hidden
        scope :visible, -> { hidden(false) }

        belongs_to :forum, class_name: 'Forem::Forum', validates: {reference: true}
        field_scope :forum
        belongs_to :user, class_name: 'User', validates: {reference: true}
        field_scope :user

        has_many :posts,
                 class_name: 'Forem::Post',
                 order: {created_at: 1},
                 dependent: :destroy

        # Denormalization

        field :posts_count, type: Integer, default: 0
        field :has_pinned_post, type: Boolean, default: false
        belongs_to :last_post, class_name: 'Forem::Post', inverse_of: nil
        scope :with_posts, -> { ne(last_post_id: nil) } # Used to filter out new topics that haven't been denormalized yet

        before_validation do
            unless posts_count && last_post
                denormalize_posts!
            end
        end

        def denormalize_posts!(*)
            q = Post.latest_for_topic(self)
            if last_post = q.first
                atomically do
                    set(last_post_id: last_post.id)
                    set(posts_count:  q.count)
                    set(has_pinned_post: q.pinned(true).exists?)
                end
            end
        end

        scope :latest_by, -> (user) {
            visible.user(user).desc(:created_at).hint(INDEX_user_hidden_created)
        }

        scope :for_forum, -> (forum) {
            forum(forum).with_posts.order_by(pinned: -1, visibly_updated_at: -1).hint(INDEX_forum_pinned_updated)
        }

        scope :announcements, -> {
            announcements = Forem::Forum.asc(:order).first
            forum(announcements).with_posts.visible.order_by(pinned: -1, created_at: -1).hint(INDEX_forum_pinned_created)
        }

        attr_accessor :moderation_option

        attr_accessible :forum, :subject, :posts, :posts_attributes,
                        as: :creator

        attr_accessible :forum, :forum_id, :subject,
                        as: :editor

        attr_accessible :locked, :pinned, :hidden,
                        as: :moderator

        accepts_nested_attributes_for :posts

        index({user_id: 1, created_at: -1})

        index(INDEX_forum_pinned_updated = {forum_id: 1, pinned: -1, visibly_updated_at: -1})
        index(INDEX_forum_pinned_created = {forum_id: 1, pinned: -1, created_at: -1})
        index(INDEX_forum_user_unread = {forum_id: 1}.merge(INDEX_user_unread))
        index(INDEX_user_hidden_created = {user_id: 1, hidden: 1, created_at: -1})

        validate :enforce_cooldown

        after_create do
            subscribe_user(user)
        end

        class << self
            def create_from_params(params, forum, user = User.current)
                attrs = params.require(:topic)

                with_assignment_role(:creator) do
                    # The post is supposed to build automatically, but it seems to be broken in Mongoid.
                    # The post object is added to the topic, calling save returns true, but it never
                    # actually gets written to the database.
                    post_attrs = attrs.delete(:posts_attributes)['0']

                    topic = forum.topics.build(attrs)
                    topic.user = user

                    if topic.save
                        # Post must be built after topic save, or the post won't save properly
                        post = topic.build_first_post(post_attrs)
                        unless post.save
                            topic.destroy
                            post.errors.full_messages.each do |msg|
                                topic.errors.add :base, msg
                            end
                        end
                    else
                        # If topic save failed, we still need a post for the form
                        topic.build_first_post(post_attrs)
                    end

                    topic
                end
            end

            def by_pinned_or_most_recent_post
                order_by(pinned: -1, visibly_updated_at: -1).hint(INDEX_forum_pinned_updated)
            end

            def whats_new
                self.in(forum: Forum.ne(home_viewable: false).to_a)
                    .visibly_updated_since(1.week.ago)
                    .by_visibly_updated
            end
        end

        def build_first_post(attrs)
            posts.first or Post.with_assignment_role(:creator) do
                post = posts.build(attrs)
                post.first_post = true
                post.user = user
                post.created_at = created_at
                post
            end
        end

        def to_s
            subject
        end

        def link
            Engine.url_helpers.topic_path(self)
        end

        def cooldown_remaining(now = Time.now)
            unless persisted?
                user = self.user || User.current
                unless user.has_permission?(:forum, forum.id.to_s, :bypass_cooldown, true)
                    if last_topic = self.class.visible.where(user: user).desc(:created_at).first
                        cooldown = last_topic.created_at + CREATE_COOLDOWN - now
                        cooldown if cooldown > 0
                    end
                end
            end
        end

        def enforce_cooldown
            if cooldown = cooldown_remaining
                errors.add(:base, "You must wait #{time_ago_shorthand(Time.now - cooldown)} before creating this topic")
            end
        end

        def indexed_posts
            Post.for_topic(self)
        end

        def pinned_posts
            Post.pinned_for_topic(self)
        end

        def index_of_post(post)
            indexed_posts.lte(created_at: post.created_at).lt(_id: post._id).count
        end

        def toggle!(field)
            send "#{field}=", !self.send("#{field}?")
            save :validation => false
        end

        # Cannot use method name lock! because it's reserved by AR::Base
        def lock_topic!
            update_attribute(:locked, true)
        end

        def unlock_topic!
            update_attribute(:locked, false)
        end

        # Provide convenience methods for pinning, unpinning a topic
        def pin!
            update_attribute(:pinned, true)
        end

        def unpin!
            update_attribute(:pinned, false)
        end

        def moderate!(option)
            send("#{option}!")
        end

        def can_be_replied_to?
            !locked? && !archived? && !hidden?
        end

        def archived?
            !(pinned? || visibly_updated_since?(2.months.ago))
        end

        def after_view(user, first_view, new_updates)
            forum.clear_unread_topics_for(user) if new_updates && !first_view

            if sub = subscriptions.user(user).one
                sub.alerts.mark_read!
            end
        end

        def mark_visibly_updated!(*args)
            super
            # Shame we have to invalidate the entire forum's unread topic count for ALL users
            # every time a post is created in the forum, but there's no simple way to avoid it.
            forum.clear_unread_topics
        end

        def self.can_create?(forum, user = User.current)
            if user
                return forum.can_manage?(user) || user.has_permission?('forum', forum.id.to_s, 'topic', 'create', true)
            end
        end

        def self.can_index?(forum, scope, user = User.current)
            user ||= User.anonymous_user
            forum.can_manage?(user) ||
                user.has_permission?('forum', forum.id.to_s, 'topic', 'index_parent', scope) ||
                (scope == 'own' && user.has_permission?('forum', forum.id.to_s, 'topic', 'index_parent', 'all'))
        end

        def can_index?(user = User.current)
            scope = user == self.user ? 'own' : 'all'
            indexable = Forem::Topic.can_index?(self.forum, scope, user)
            indexable = indexable && Forem::Topic.can_index_criteria?(self.forum, [:status, :locked], scope, user) if self.locked?
            indexable = indexable && Forem::Topic.can_index_criteria?(self.forum, [:status, :hidden], scope, user) if self.hidden?
            indexable
        end

        def self.can_index_criteria?(forum, criteria, scope, user = User.current)
            user ||= User.anonymous_user
            forum.can_manage?(user) ||
                (Forem::Topic.can_index?(forum, scope, user) &&
                    (user.has_permission?('forum', forum.id.to_s, 'topic', 'index', *criteria, scope) ||
                        (scope == 'own' && user.has_permission?('forum', forum.id.to_s, 'topic', 'index', *criteria, 'all'))))
        end

        def can_view?(user = User.current)
            if self.forum.can_manage?(user)
                return true
            end
            scope = user == self.user ? 'own' : 'all'
            visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'view_parent', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'view_parent', 'all'))
            visible = visible && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'view', 'status', 'hidden', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'view', 'status', 'hidden', 'all')) if self.hidden?
            visible = visible && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'view', 'status', 'locked', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'view', 'status', 'locked', 'all')) if self.locked?
            visible
        end

        def can_reply?(user = User.current)
            if user
                if self.forum.can_manage?(user)
                    return true
                end
                scope = user == self.user ? 'own' : 'all'
                visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'reply', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'reply', 'all'))
                visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.hidden?
                visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.locked?
                visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.archived?
                visible
            end
        end

        def can_lock?(user = User.current)
            return false if self.locked?
            if user
                if self.forum.can_manage?(user)
                    return true
                end
                scope = user == self.user ? 'own' : 'all'
                visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'lock', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'lock', 'all'))
                visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.hidden?
                visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.archived?
                visible
            end
        end

        def can_unlock?(user = User.current)
            return false unless self.locked?
            if user
                if self.forum.can_manage?(user)
                    return true
                end
                scope = user == self.user ? 'own' : 'all'
                visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'unlock', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'unlock', 'all'))
                visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.hidden?
                visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.locked?
                visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.archived?
                visible
            end
        end

        def can_hide?(user = User.current)
            return false if self.hidden?
            if user
                if self.forum.can_manage?(user)
                    return true
                end
                scope = user == self.user ? 'own' : 'all'
                visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'hide', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'hide', 'all'))
                visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.locked?
                visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.archived?
                visible
            end
        end

        def can_approve?(user = User.current)
            return false unless self.hidden?
            if user
                if self.forum.can_manage?(user)
                    return true
                end
                scope = user == self.user ? 'own' : 'all'
                visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'approve', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'approve', 'all'))
                visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.hidden?
                visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.locked?
                visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.archived?
                visible
            end
        end

        def can_pin?(user = User.current)
            return false if self.pinned?
            if user
                if self.forum.can_manage?(user)
                    return true
                end
                scope = user == self.user ? 'own' : 'all'
                visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'pin', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'pin', 'all'))
                visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.hidden?
                visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.locked?
                visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.archived?
                visible
            end
        end

        def can_unpin?(user = User.current)
            return false unless self.pinned?
            if user
                if self.forum.can_manage?(user)
                    return true
                end
                scope = user == self.user ? 'own' : 'all'
                visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'unpin', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'unpin', 'all'))
                visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.hidden?
                visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.locked?
                visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.archived?
                visible
            end
        end

        def can_edit_title?(user = User.current)
            if user
                if self.forum.can_manage?(user)
                    return true
                end
                scope = user == self.user ? 'own' : 'all'
                visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'edit_title', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'edit_title', 'all'))
                visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.hidden?
                visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.locked?
                visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.archived?
                visible
            end
        end

        def can_move?(user = User.current)
            if user
                if self.forum.can_manage?(user)
                    return true
                end
                scope = user == self.user ? 'own' : 'all'
                visible = user.has_permission?('forum', self.forum.id.to_s, 'topic', 'move', scope) || (scope == 'own' && user.has_permission?('forum', self.forum.id.to_s, 'topic', 'move', 'all'))
                visible = visible && Forem::Topic.can_modify_hidden?(self.forum, scope, user) if self.hidden?
                visible = visible && Forem::Topic.can_modify_locked?(self.forum, scope, user) if self.locked?
                visible = visible && Forem::Topic.can_modify_archived?(self.forum, scope, user) if self.archived?
                visible
            end
        end

        def can_moderate?(user = User.current)
            MODERATION_ACTIONS.any?{|action| __send__("can_#{action}?", user) }
        end

        def self.can_modify_hidden?(forum, scope, user = nil)
            user && (user.has_permission?('forum', forum.id.to_s, 'topic', 'modify_hidden', scope) || (scope == 'own' && user.has_permission?('forum', forum.id.to_s, 'topic', 'modify_hidden', 'all')))
        end

        def self.can_modify_locked?(forum, scope, user = nil)
            user && (user.has_permission?('forum', forum.id.to_s, 'topic', 'modify_locked', scope) || (scope == 'own' && user.has_permission?('forum', forum.id.to_s, 'topic', 'modify_locked', 'all')))
        end

        def self.can_modify_archived?(forum, scope, user = nil)
            user && (user.has_permission?('forum', forum.id.to_s, 'topic', 'modify_archived', scope) || (scope == 'own' && user.has_permission?('forum', forum.id.to_s, 'topic', 'modify_archived', 'all')))
        end
    end
end
