module TokenAuthenticatable
    extend ActiveSupport::Concern

    KEY_PERMISSION = ['api', 'key', true]
    VERIFY_PERMISSION = ['api', 'verify', true]
    COMMIT_PERMISSION = ['api', 'commit', true]

    KEY_HEADER = 'X-OCN-Key'
    KEY_LENGTH = 32

    class << self
        def digest_key(key)
            OpenSSL::Digest::SHA256.hexdigest(key)
        end

        def create_key
            SecureRandom.base64(KEY_LENGTH).gsub(/=/, '')
        end
    end

    included do
        field :api_key_digest, type: String
        index({api_key_digest: 1}, {unique: true, sparse: true})
    end # included do

    def can_auth_with_key?
        has_permission?(KEY_PERMISSION)
    end

    def assert_api_access
        assert_permission(KEY_PERMISSION)
    end

    def has_api_key?
        can_auth_with_key? && !api_key_digest.nil?
    end

    def generate_api_key!(check_access: true)
        assert_api_access if check_access
        key = TokenAuthenticatable.create_key
        self.api_key_digest = TokenAuthenticatable.digest_key(key)
        save!
        key
    end

    def revoke_api_key!
        self.api_key_digest = nil
        save!
    end

    module ClassMethods
        def find_by_api_key(key)
            digest = TokenAuthenticatable.digest_key(key)
            if User.console_user.api_key_digest == digest
                # Console user is used by bots. It's not actually saved
                # in the DB, so it needs a special check.
                User.console_user
            elsif user = find_by(api_key_digest: digest)
                user.assert_api_access
                user
            end
        end
    end # ClassMethods
end # TokenAuthenticatable
