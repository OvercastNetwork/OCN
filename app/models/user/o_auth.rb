class User
    module OAuth
        extend ActiveSupport::Concern
        include Mongoid::Document

        class Token
            include Mongoid::Document
            embedded_in :user

            field :service, type: String
            field :access_token, type: String
            field :refresh_token, type: String
            field :refreshed_at, type: String
            field :expires_at, type: Time

            def service
                self[:service].to_sym
            end

            attr_accessible :service, :access_token, :refresh_token, :refreshed_at, :expires_at

            def to_client(client = nil)
                client ||= OAuth.create_client_for(service)
                client.access_token = self.access_token
                client.refresh_token = self.refresh_token
                client
            end

            def from_client(client)
                self.service = client.state if client.state
                self.access_token = client.access_token if client.access_token
                self.refresh_token = client.refresh_token if client.refresh_token

                if client.expires_at
                    self.expires_at = client.expires_at
                    self.refreshed_at = client.expires_at - client.expires_in
                else
                    self.refreshed_at = Time.now
                    self.expires_at = self.refreshed_at + 1.minute # wild guess
                end
            end

            def fresh_client
                client = to_client
                if access_token.nil? || Time.now + 1.minute > expires_at # Refresh if less than a minute left
                    begin
                        client.grant_type = 'refresh_token'
                        client.refresh!
                        from_client(client)
                    rescue Signet::AuthorizationError
                        destroy
                        return nil
                    end

                    save!
                end
                client
            end
        end

        included do
            embeds_many :oauth2_tokens, class_name: 'User::OAuth::Token'

            index({'oauth2_tokens.service' => 1})
        end

        class << self
            def create_client_for(service)
                service = service.to_sym
                if client = Rails.configuration.oauth2_client_secrets[service]
                    client = client.to_authorization
                    client.state = service.to_s
                    client.grant_type = 'authorization_code'

                    case service
                        when :youtube
                            client.scope = 'https://www.googleapis.com/auth/youtube.readonly'
                    end
                end

                client
            end
        end

        module ClassMethods
            def with_oauth2_token_for(service)
                where('oauth2_tokens.service' => service)
            end
        end

        def find_oauth2_token_for(service)
            oauth2_tokens.find_by(service: service.to_s)
        end

        def create_oauth2_token_for(service)
            oauth2_tokens.new(service: service)
        end

        def oauth2_token_for(service)
            find_oauth2_token_for(service) || create_oauth2_token_for(service)
        end
    end
end
