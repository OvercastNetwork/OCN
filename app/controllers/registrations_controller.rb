class RegistrationsController < Devise::RegistrationsController

    def new
        @token = Array.new(12){[*'0'..'9', *'a'..'z'].sample}.join
        @url = "register.#{ORG::DOMAIN}"
    end

    def create
        email = params[:email]
        user = nil

        if !User.email_valid?(email)
            email_result = 'invalid'
        elsif User.email_registered?(email)
            email_result = 'registered'
        else
            email_result = 'available'

            if user = User.where(register_token: params[:token])
                          .find_one_and_update({$unset => {register_token: true}}, return_document: :after)
                user.email = email
                user.send_confirmation_instructions
            end
        end

        render :json => {:success => !user.nil?, :email_result => email_result, :username => (user.username if user)}
    end

    def edit
        @user = current_user
        @disabled = @user.banned_updates
    end

    def update
        return redirect_to_back edit_user_registration_path, :alert => 'Nothing to update.' if params[:user].nil?
        return redirect_to_back edit_user_registration_path, :alert => "An unknown error has occurred. If the problem persists, please email #{ORG::EMAIL}" unless @user = User.find(current_user.id)

        banned_updates = @user.banned_updates

        form = params[:user]
        form.delete_if{|key, value| banned_updates.include? key.to_sym}

        return redirect_to_back edit_user_registration_path, :alert => 'You must be a premium user to change your default server' unless @user.can_set_default_server?
        return redirect_to_back edit_user_registration_path, :alert => 'Invalid gender specified' unless ['Male', 'Female', '', nil].include? form[:gender]

        email_available = User.email_available?(form[:email])
        email_changed = (@user.email != form[:email].to_s.strip && !form[:email].to_s.strip.blank?)
        email_update = email_changed && email_available

        password_available = form[:password].to_s.size.in?(Devise.password_length)
        password_changed = !form[:password].to_s.strip.blank? || !form[:password_confirmation].to_s.strip.blank?

        password_entered = !form[:current_password].to_s.strip.blank?

        # Parse emails (model does further cleanup)
        form[:external_emails] &&= form[:external_emails].lines.to_a

        # if we have an available email and the email has changed and the current password entered
        # OR
        # if we have an availalbe password and the password has changed and the current passwor entered
        successfully_updated = @user.with_assignment_role(:user) do
            if password_entered && (email_update || password_changed)
                @user.update_with_password(form)
            elsif !password_entered && !email_changed && !password_changed
                @user.update_without_password(form)
            else
                false
            end
        end

        if successfully_updated
            # Sign in the user bypassing validation in case his password changed
            sign_in @user, :bypass => true

            # remind the user their email is unconfirmed
            alert = "Your unconfirmed email is #{@user.unconfirmed_email}. Please check your email." if email_update && @user.unconfirmed_email.present?

            redirect_to_back edit_user_registration_path, :notice => "Information Updated", :alert => alert
        else
            msg = "Your current password was incorrect." if password_changed || email_changed
 
            if password_entered
                msg = "Your new password was not long enough." if password_changed && !password_available
                msg = "Your new passwords do not match." if form[:password] != form[:password_confirmation]
                msg = "You did not change your email or password" if !email_changed && !password_changed
            else
                msg = "You need your current password to change your email or password." if email_changed || password_changed
            end

            msg = "Your new email is already taken" if email_changed && !email_available
            msg = "Could not update information" if msg.nil?

            redirect_to_back edit_user_registration_path, :flash => {:error => "Error: " + msg}
        end
    end

    def destroy
    end

    def oauth2_authorize
        if params[:service] and client = User::OAuth.create_client_for(params[:service])
            redirect_to client.authorization_uri(approval_prompt: 'force').to_s
        else
            render status: 400, text: "Bad service"
        end
    end

    def oauth2_callback
        if code = params[:code] and service = params[:state]
            token = current_user.oauth2_token_for(service)
            client = token.to_client
            client.code = code
            client.grant_type = 'authorization_code'

            client.fetch_access_token!

            token.from_client(client)
            token.save!

            Channel::Youtube.refresh_for_user!(current_user)

            redirect_to edit_user_registration_path, notice: "Authorization successful"
        else
            redirect_to edit_user_registration_path, error: "Authorization failed"
        end
    end

    def api_key
        unless @api_key = flash[:api_key]
            redirect_to edit_user_registration_path
        end

        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate" # HTTP 1.1.
        response.headers["Pragma"] = "no-cache" # HTTP 1.0.
        response.headers["Expires"] = "0" # Proxies.
    end

    def generate_api_key
        redirect_to :api_key, flash: {api_key: current_user.generate_api_key!}
    end

    def revoke_api_key
        current_user.revoke_api_key!
        redirect_to edit_user_registration_path, alert: "API key revoked"
    end
end
