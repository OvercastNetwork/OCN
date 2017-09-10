module Api
    class FriendshipsController < ModelController
        controller_for Friendship

        def create
            friender = player_param(:friender_id)
            friended = player_param(:friended_id)

            return respond success: false, error: "not_self" if friender == friended
            return respond success: false, error: "friend_limit" unless friender.can_request_friends?
            return respond success: false, error: "not_accepting" unless friended.accept_friend_requests?

            if friendship = Friendship.betwixt(friender, friended).one
                return respond success: false, error: "already_friends" if friendship.accepted?
                return respond success: false, error: "you_already_requested" if friendship.friender == friender 
                if friendship.friended == friender
                    friendship.decide!(true)
                    respond success: true, friendships: [friendship.api_document]
                end
            end

            friendship = Friendship.new(friender: friender, friended: friended)
            if friendship.save
                respond success: true, friendships: [friendship.api_document]
            else
                respond success: false, error: "error"
            end
        end

        def destroy
            friender = player_param(:friender_id)
            friended = player_param(:friended_id)

            if friendship = Friendship.from_to(friender, friended).one
                unless friendship.rejected?
                    if friendship.destroy
                        respond success: true, friendships: []
                    else
                        respond success: false, error: "error"
                    end
                else
                    respond success: false, error: "pending"
                end
            else
                respond success: false, error: "not_friends"
            end
        end

        def list
            friender = player_param(:friender_id)
            respond success: true, friendships: Friendship.friender(friender).limit(1000)
        end
    end
end
