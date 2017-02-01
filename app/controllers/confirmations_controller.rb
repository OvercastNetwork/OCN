class ConfirmationsController < Devise::ConfirmationsController
    def new
        redirect_to controller: 'registrations', action: 'new'
    end

    def show
        if params[:confirmation_token]
            token = Devise.token_generator.digest(User.class, :confirmation_token, params[:confirmation_token])
            @user = User.where(:confirmation_token => token).first

            if @user.nil?
                flash[:error] = find_message(:invalid_token)
                redirect_to controller: 'registrations', action: 'new'
            elsif @user.email.present? && @user.pending_reconfirmation?
                if user_signed_in?
                    @user.confirm!
                    redirect_to edit_user_registration_path, :alert => "You have successfully confirmed your new email #{@user.email}"
                else
                    redirect_to new_user_session_path, :alert => "Please sign into your existing account to confirm your new email"
                end
            end
        else
            redirect_to controller: 'registrations', action: 'new'
        end
    end

    def confirm_account
        @user = User.where(:confirmation_token => params[:user][:confirmation_token]).first

        return redirect_to_back user_confirmation_path, :alert => "Invalid token, please contact #{ORG::EMAIL} if the issue persists" if @user.nil?

        if @user.valid? && @user.reset_password!(params[:user][:password], params[:user][:password_confirmation])
            @user.confirm!
            Trophy['sign-up'].give_to(@user)

            set_flash_message :notice, :confirmed
            sign_in_and_redirect("user", @user)
        else
            render :action => "show"
        end
    end
end
