class SantaController < ApplicationController
    before_filter :valid_user, :except => [:index, :done]
    before_filter :block_banned_users, :only => [:create]

    def index
        @purchases = Package.purchases_by_id
        @gift = Gift.user(current_user).giveable.first_or_initialize if user_signed_in?

        @wishful = a_page_of(Gift.wishful_elves.prefetch(:user, :package), key: :wishful_page)
        @happy = a_page_of(Gift.happy_children.prefetch(:user, :package), key: :happy_page)
    end

    def create
        if Gift.has_open_request?
            redirect_to_back(santa_path, alert: "You have already asked for a gift")
        else
            @gift = Gift.new(params[:gift])
            @gift.user = current_user

            if @gift.save
                redirect_to_back(santa_path, notice: "Request posted")
            else
                redirect_to_back(santa_path, flash: {error: @gift.errors.full_messages.first})
            end
        end
    end

    def raindrops
        raindrops = int_param(:raindrops, required: true)
        gift = model_param(Gift.giveable.ne(user: current_user_safe), required: true)

        if raindrops > 0 && current_user_safe.debit_raindrops(raindrops)
            gift.inc(raindrops: raindrops)
        end

        redirect_to santa_path + "#" + gift.id
    end

    def destroy
        q = Gift.giveable
        q = q.user(current_user_safe) unless current_user_safe.admin?
        gift = model_param(q, required: true)

        if gift.destroy
            redirect_to_back(santa_path, notice: "Request removed")
        else
            render :index, alert: "Can't destroy that request"
        end
    end
end
