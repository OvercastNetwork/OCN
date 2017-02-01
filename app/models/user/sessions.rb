class User
    module Sessions
        extend ActiveSupport::Concern
        include RequestCacheable

        included do
            attr_cached :current_session do
                Session.last_online_started_by(self)
            end
        end
    end
end
