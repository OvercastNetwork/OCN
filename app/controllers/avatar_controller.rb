class AvatarController < ActionController::Base
    rescue_from Exception, :with => :error

    def show
        return not_found unless @player = User.by_username_or_id(params[:name])

        # Size is always doubled for retina support
        size = (params[:size] || 32).to_i * 2
        return render status: 400, text: "Invalid image size" unless size > 0

        send_data @player.avatar(size).to_blob, type: 'image/png', disposition: 'inline'
    end

    def not_found
        render :text => nil, :layout => false, :status => 404
    end

    def error(exception)
        Raven.capture_exception(exception)
        render :text => nil, :layout => false, :status => 500
    end
end
