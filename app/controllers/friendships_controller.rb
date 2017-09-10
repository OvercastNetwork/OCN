class FriendshipsController < ApplicationController
    before_filter :valid_user
    before_filter :find_friendship, :only => [:update, :destroy]
    layout "application"

    def index
        @offline_friends = current_user.friends.to_a
        @online_friends = []
        servers = Server.online.visible_to_public.left_join_sessions(Session.online.right_join_users(@offline_friends))

        servers.each do |server|
            server.joined_sessions.each do |session|
                @online_friends << {friend: session.player, datacenter: server.datacenter.upcase, server: server}
                @offline_friends.delete(session.player)
            end
        end
    end

    def pending
        @requests = a_page_of Friendship.undecided.involving(current_user_safe).desc(:sent_date)
    end

    def denied
        @denials = a_page_of Friendship.rejected.friended(current_user_safe)
    end

    def create
        return_to user_path(user = model_param(User, :user_id))

        current_user_safe.can_request_friends? or raise Back.new(alert: "You must upgrade to a premium rank to add more than #{Friendship.max_default_friends} friends")

        if friendship = Friendship.betwixt(current_user_safe, user).one
            friendship.accepted? and raise Back.new(alert: "You are already friends with #{user.username}")
            friendship.friender == current_user_safe and raise Back.new(alert: "You have already requested to be friends with #{user.username}")
            friendship.friended == current_user_safe and raise Back.new(alert: "#{user.username} has already requested to be friends with you")
        end

        user.accept_friend_requests? or raise Back.new(alert: "#{user.username} is not accepting friend requests")

        if Friendship.new(friender: current_user, friended: user).save
            redirect_to_back
        else
            raise Back.new(alert: "Friend request failed to send")
        end
    end

    def update
        raise Back.new(alert: "No permission") unless @friendship.can_update?(current_user_safe)
        @friendship.update_attributes!(decision: params[:decision] == 'true')
        redirect_to_back
    end

    def destroy
        raise Back.new(alert: "No permission") unless @friendship.can_destroy?(current_user_safe)
        @friendship.destroy
        redirect_to_back
    end

    protected

    def find_friendship
        @friendship = model_param(Friendship)
    rescue Mongoid::Errors::DocumentNotFound
        @friend = model_param(User)
        @friendship = model_one(Friendship.betwixt(current_user_safe, @friend))
    end
end
