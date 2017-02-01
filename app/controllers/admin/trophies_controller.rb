module Admin
    class TrophiesController < BaseController

        before_filter :find_trophy, :only => [:update_membership]
        skip_before_filter :authenticate_admin

        def self.general_permission
            ['trophy', 'admin', true]
        end

        def index
            @trophies = Trophy.all
        end

        def update_membership
            not_found unless user = User.by_username(params[:user])

            if params[:task] == "add"
                @trophy.give_to(user)
            else
                @trophy.take_from(user)
            end

            return redirect_to_back(admin_trophies_path)
        end

        protected

        def find_trophy
            @trophy = model_param(Trophy)
        end
    end
end
