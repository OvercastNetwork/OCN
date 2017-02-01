# Allows a user to authenticate with an API key in an HTTP header.
# The "strategy" is registered with Devise in devise.rb

Warden::Strategies.add(:api_key) do
    def valid?
        request.headers[TokenAuthenticatable::KEY_HEADER]
    end

    def authenticate!
        if user = User.find_by_api_key(request.headers[TokenAuthenticatable::KEY_HEADER])
            success! user
        else
            fail! "Bad API key"
        end
    end
end

# Digest of the API key for User.console_user
# The actual key is not in the source code
CONSOLE_USER_KEY_DIGEST = "..."
