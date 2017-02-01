module Admin
    class UsersController < BaseController
        breadcrumb "Users"

        before_filter :find_user, :only => [:edit, :update, :become, :clear_channels]


        def index
        end

        def edit
        end

        def update
            @user.with_assignment_role(:user) do
                if @user.update_attributes(params[:user]) && @user.update_attribute(:restricted_fields, params[:restricted].nil? ? [] : params[:restricted].keys)
                    redirect_to edit_admin_user_path(@user), :notice => "User updated"
                else
                    redirect_to_back edit_admin_user_path(@user), :alert => "Error updating user"
                end
            end
        end

        def become
            sign_in(:user, @user, bypass: true) # bypass means don't update last login times
            redirect_to root_path
        end

        def clear_channels
            @user.channels=[]
            @user.save!
            redirect_to edit_admin_user_path(@user), :alert => "User's channels have been cleared"
        end

        private

        def find_user
            return not_found unless @user = User.by_username(params[:id]) || User.by_uuid(params[:id]) || User.find(params[:id])
            breadcrumb @user.username
        end
    end
end
