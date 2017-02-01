class User
    # Failure to claim a register token, with a user-friendly message
    class RegisterError < Exception
    end

    # Part of the registration system used to connect a web user to a Minecraft account
    module MinecraftRegistration
        extend ActiveSupport::Concern

        REGISTER_TOKEN_REGEX = /\A[0-9a-z]{12}\z/

        included do
            field :register_token, type: String
            validates_format_of :register_token, with: REGISTER_TOKEN_REGEX, allow_nil: true
            index({register_token: 1}, {unique: true, sparse: true})

            after_initialize :normalize_register_token
            before_validation :normalize_register_token
            before_save :normalize_register_token
        end # included do

        def normalize_register_token
            self.register_token = self.register_token.downcase.strip if self.register_token
        end

        # Validates and claims the given register_token, and saves the user.
        # Called when a user connects to *.register.some.network
        # Raises RegisterError if something goes wrong
        def claim_register_token(token)
            if self.confirmed?
                raise RegisterError, "You have already confirmed your account\n\nEmail: #{self.email}"
            elsif token !~ User::REGISTER_TOKEN_REGEX
                raise RegisterError, "That register token looks wrong\n\nPlease check it and try connecting again"
            else
                begin
                    self.where_self.find_one_and_update($set => {register_token: token})
                rescue Mongo::Error::OperationFailure # duplicate index key
                    raise RegisterError, "Someone else has already registered with that token\n\nPlease return to the website and start again"
                end
            end
        end

        module ClassMethods
            # Generate a random and unique register_token
            def generate_register_token
                charset = [*0..9, *'a'..'z']
                100.times do
                    token = 12.times.map{ charset.sample }.join
                    return token unless where(register_token: token).exists?
                end
            end
        end # ClassMethods
    end # Registration
end
