require 'google/api_client'

Rails.configuration.tap do |config|
    config.google = {
        :production => {
            :secret => "...",
            :identifier => "..."
        },

        :development => {
            :secret => "...",
            :identifier => "..."
        }
    }

    config.google_encode = "..."

    config.google_api_key = "..."

    config.oauth2_client_secrets = {
        youtube: Google::APIClient::ClientSecrets.new(
            'web' => {
                client_id: "xxx.apps.googleusercontent.com",
                client_secret: "...",
                redirect_uri: "...",
                javascript_origin: "...",
            }
        ),
    }
end

module GOOGLE
    extend self

    def new_client(**options)
        options[:authorization] ||= nil # Without this, it creates an OAuth2 client
        options[:key] &&= Rails.configuration.google_api_key
        Google::APIClient.new(application_name: 'OCN', **options)
    end

    # CLIENT = new_client
    # KEY_CLIENT = new_client(key: true)
    # YOUTUBE = KEY_CLIENT.discovered_api('youtube', 'v3')
end

