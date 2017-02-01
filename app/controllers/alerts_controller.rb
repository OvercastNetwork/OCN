class AlertsController < ApplicationController
    before_filter :valid_user

    def index
        @all_alerts = a_page_of Alert.user(current_user_safe).desc(:updated_at)
    end

    def show
        alert = model_param(Alert.user(current_user_safe))
        alert.mark_read!

        if alert.link
            redirect_to alert.link
        else
            redirect_to_back # TODO: can this be relied on to take them back to the right page?
        end
    end

    def read_all
        Alert.user(current_user_safe).mark_read!
        redirect_to_back alerts_path, :alert => "Marked all alerts as read"
    end
end
