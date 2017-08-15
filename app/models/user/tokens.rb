class User
    module Tokens
        extend ActiveSupport::Concern

        included do
            field :raindrops, type: Integer, default: 0
            field :maptokens, type: Integer, default: 0
            field :mutationtokens, type: Integer, default: 0

            field :friend_tokens_window, type: Array, default: []
            field :friend_tokens_limit, type: Integer, default: 0
            field :friend_tokens_concurrent, type: Integer, default: 0

            attr_accessible :raindrops, :maptokens, :mutationtokens,
                            :friend_tokens_window, :friend_tokens_limit, :friend_tokens_concurrent

            api_property :raindrops, :maptokens, :mutationtokens,
                         :friend_tokens_window, :friend_tokens_limit, :friend_tokens_concurrent

            index({raindrops: 1})
        end

        def credit_tokens(type, amount)
            return nil if anonymous?
            if amount > 0
                inc(type => amount)
                self
            elsif amount < 0
                where_self
                    .gte(type => -amount)
                    .find_one_and_update({$inc => {type => amount}},
                                         return_document: :after)
            else
                self
            end
        end

        def debit_tokens(type, amount)
            credit_tokens(type, -amount)
        end

        def friend_token(amount)
            # Update tokens to removed expired entries
            expired = friend_tokens_window.select{|time| time + 1.day < Time.now}
            unless expired.empty?
                self.friend_tokens_window = friend_tokens_window - expired
            end
            # See if a new token can be added
            if friend_tokens_window.size < friend_tokens_limit
                self.add_to_set(friend_tokens_window: Time.now)
                self.save
            end
        end

        def next_friend_token
            friend_tokens_window.empty? ? nil : friend_tokens_window[0] + 1.day
        end

        def remaining_friend_token
            [0, friend_tokens_limit - friend_tokens_window.size].max
        end

        # Purchase the gizmo represented by the given Group for the given price,
        # returning the updated User document if the purchase was successful, or nil if
        # it failed. The purchase will fail if the user does not have enough raindrops
        # or if they already own the gizmo.
        def purchase_gizmo(group, price)
            # Assume memberships in the given group are always permanent, and so
            # if the user is not a member then it's safe to $push a new Membership.
            membership = Group::Membership.new(group: group,
                                               start: Time.now,
                                               stop: Time::INF_FUTURE)
            membership.validate!

            self.where_self
                .without_membership(group_id: group.id)
                .gte(raindrops: price)
                .find_one_and_update({$inc => {raindrops: -price}, $push => {memberships: membership.as_document}},
                                     return_document: :after)
        end
    end
end
