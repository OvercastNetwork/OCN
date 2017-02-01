module Forem
    class Forum
        include Mongoid::Document
        store_in :database => "oc_forem_forums"

        field :title
        belongs_to :category, :class_name => 'Forem::Category'
        has_many :topics, :class_name => 'Forem::Topic'

        # Caching
        field :posts_count, :type => Integer, :default => 0

        field :order, :type => Integer, :default => 0

        field :home_viewable, :type => Boolean, :default => true

        field :simple_forum_style, :type => Boolean, :default => false

        field :description, type: String

        validates :category_id, :presence => true
        validates :title, :presence => true

        attr_accessible :category_id, :title, :order, :home_viewable, :simple_forum_style, :description

        class << self
            def by_order
                asc(:order)
            end
        end

        def increment_posts_count!
            inc(posts_count: 1)
        end

        def unread_topics_for_full(user)
            topics
                .hidden(false)
                .visibly_updated_for(user)
                .hint(Forem::Topic::INDEX_forum_user_unread)
                .count
        end

        def mark_topics_read_by(user = User.current, now: Time.now)
            topics
                .hint(Forem::Topic::INDEX_forum_user_unread)
                .mark_all_viewed_by(user, now: now)
            clear_unread_topics_for(user)
        end

        # REDIS
        def key(symbol)
            "cache:forum:#{id}:#{symbol}"
        end

        def unread_topics_for(user = User.current)
            return 0 if user.anonymous?

            key = self.key(:unread)
            unless unread = REDIS.hget(key, user.player_id)
                unread = unread_topics_for_full(user)
                REDIS.hset(key, user.player_id, unread)
            end
            unread.to_i
        end

        def clear_unread_topics_for(user)
            REDIS.hdel(key(:unread), user.player_id) unless user.anonymous?
        end

        def clear_unread_topics
            REDIS.del(self.key(:unread))
        end
        # REDIS END

        def can_manage?(user = nil)
            user && (user.admin? || user.has_permission?('forum', self.id.to_s, 'manage', true))
        end

        def can_view?(user = nil)
            Forem::Topic.can_index?(self, 'own', user)
        end
    end
end
