# A model that tracks which Users have viewed it, when they last viewed it,
# and the number of updates that have happened since (i.e. the "unread" count).
module Viewable
    extend ActiveSupport::Concern
    include Mongoid::Document

    INDEX_visibly_updated_at = {visibly_updated_at: -1}
    INDEX_user_unread = {'views.user' => 1, 'views.unread' => 1}

    included do
        field :visibly_updated_at, type: Time, allow_nil: false, default: Time::INF_PAST
        field :views_count, type: Integer, default: 0
        field :views, type: Array, default: [].freeze

        scope :with_view, -> (attrs) { elem_match(views: attrs) }
        scope :without_view, -> (attrs) { self.not(views: {$elemMatch => attrs}) }
        scope :viewed_by, -> (user) { with_view(user: user.player_id) }
        scope :unviewed_by, -> (user) { without_view(user: user.player_id) }

        scope :visibly_updated_for, -> (user) { with_view(user: user.player_id, unread: {$ne => 0}) }
        scope :visibly_updated_since, -> (time) { gte(visibly_updated_at: time).hint(INDEX_visibly_updated_at) }
        scope :by_visibly_updated, -> { desc(:visibly_updated_at).hint(INDEX_visibly_updated_at) }

        index(INDEX_visibly_updated_at)
        index(INDEX_user_unread)
    end # included do
    
    module ClassMethods
        def tracks_views_for?(user)
            user && user.player_id? && !user.anonymous?
        end

        # Mark all selected instances that have been viewed by
        # the given user as fully read for that user.
        def mark_all_viewed_by(user = User.current, now: Time.now)
            return unless tracks_views_for?(user)

            visibly_updated_for(user).set('views.$' => {
                user: user.player_id,
                unread: 0,
                last_seen: now
            })
        end
    end # ClassMethods

    delegate :tracks_views_for?, to: :class

    def visibly_updated_since?(time)
        visibly_updated_at > time
    end

    # Mark this instance as visibly updated at the given time.
    # Users who last viewed this instance at or before that time
    # will have their unread count incremented by the given amount.
    #
    # This is an atomic update, and does not modify self.
    def mark_visibly_updated!(time = Time.now.utc, unread: 1)
        atomically do
            atomic_max(visibly_updated_at: time)
            if unread > 0
                views.each_with_index do |view, idx|
                    if view['last_seen'] <= time
                        inc("views.#{idx}.unread" => unread)
                    end
                end
            end
        end
    end

    def viewed_by?(user)
        !view_for(user).nil?
    end

    def last_seen_by(user)
        view = view_for(user) and view['last_seen']
    end

    def unread_count_for(user)
        view = view_for(user) and view['unread']
    end

    def visibly_updated_for?(user)
        unread = unread_count_for(user) and unread > 0
    end

    # Called when a user views this object
    def after_view(user, first_view, new_updates)
    end

    def register_view_by!(user = User.current, now: Time.now)
        return unless tracks_views_for?(user)

        attrs = {'user' => user.player_id, 'unread' => 0, 'last_seen' => now}

        if view = view_for(user)
            # User has viewed this thing before
            updates = {$set => {:'views.$' => attrs}}
            if new_updates = view['unread'] > 0
                # There are new items since the last view, bump the view count
                updates.merge($inc => {views_count: 1})
            end

            where_self.viewed_by(user).update(updates)
            reload

            after_view(user, false, new_updates)
        else
            # User is viewing this thing for the first time, create their view
            # record and bump the view count.
            where_self.unviewed_by(user).update(
                $push => {views: attrs},
                $inc => {views_count: 1}
            )
            reload

            after_view(user, true, true)
        end
    end

    private

    def view_for(user)
        tracks_views_for?(user) && views.find{|v| v['user'] == user.player_id}
    end
end
