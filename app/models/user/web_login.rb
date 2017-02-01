class User
    # A few fields that track info about website logins
    module WebLogin
        extend ActiveSupport::Concern

        included do
            field :suspended, type: Boolean, default: false

            field :sign_in_count, type: Integer, default: 0

            field :current_sign_in_at, type: Time
            field :current_sign_in_ip, type: String

            field :last_sign_in_at, type: Time
            field :last_sign_in_ip, type: String

            field :last_page_load_at, type: Time
            field :last_page_load_ip, type: String

            field :web_ips, type: Array

            index({last_page_load_at: 1})
        end # included do

        # Devise calls this
        def active_for_authentication?
            super && !suspended?
        end

        # Devise also calls this, but only for password login, not key auth
        def valid_password?(password)
            super && has_permission?('site', 'login', true)
        end
    end # WebLogin
end
