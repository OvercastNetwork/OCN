# Silence template render logging in production
if Rails.env.production?
    [:render_template, :render_partial, :render_collection].each do |event|
        ActiveSupport::Notifications.unsubscribe "#{event}.action_view"
    end
end
