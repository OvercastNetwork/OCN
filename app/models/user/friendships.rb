class User
    module Friendships
        extend ActiveSupport::Concern
        include RequestCacheable

        included do
            field :receive_requests, type: Boolean, default: true
            alias_method :accept_friend_requests?, :receive_requests

            attr_accessible :receive_requests, as: :user

            api_synthetic :friends do
                friends.map(&:api_player_id)
            end

            attr_cached :friendships do
                Friendship.accepted.involving(self).to_a
            end

            attr_cached :friends do
                User.in(id: friendships.flat_map(&:user_ids) - [id])
            end
        end

        def can_request_friends?
            premium? || friends.count < Friendship.max_default_friends
        end

        def friend?(user = User.current)
            self == user || if friendships_cached?
                friendships.any?{|f| f.involves? user }
            else
                Friendship.friends?(self, user)
            end
        end

        def clear_friendship_cache
            invalidate_friendships!
            invalidate_friends!
        end
    end
end
