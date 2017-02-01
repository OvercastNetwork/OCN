class User
    EMAIL_REGEX = /\A[^@\s]+@[^.@\s]+\.[^@\s]+\z/

    # Website registration, email addresses, passwords, and Devise integration
    module WebRegistration
        extend ActiveSupport::Concern
        include Mongoid::Document

        included do
            field :email, type: String
            field :unconfirmed_email, type: String

            field :confirmation_token, type: String
            field :confirmation_sent_at, type: Time
            field :confirmed_at, type: Time

            field :encrypted_password, type: String
            field :reset_password_token, type: String
            field :reset_password_sent_at, type: Time

            # Used by the Devise Rememberable module
            field :remember_created_at, type: Time

            validates :email, :unconfirmed_email,
                      email: true, allow_nil: true

            attr_accessible :confirmation_sent_at

            # Devise fields
            attr_accessible :password, :password_confirmation, :remember_me
            attr_accessible :password, :password_confirmation, :email, as: :user

            index({email: 1}, {sparse: true})
            index({unconfirmed_email: 1})

            index({confirmed_at: 1})
            index({confirmation_token: 1})

            index({reset_password_token: 1})

            after_initialize :normalize_email_fields
            before_validation :normalize_email_fields
            before_save :normalize_email_fields
        end # included do

        def normalize_email_fields
            self.email = User.normalize_email(self.email)
            self.unconfirmed_email = User.normalize_email(self.unconfirmed_email)
        end

        # The two methods below override methods in Devise's validation module,
        # in order to allow users to exist without an email or password, but still
        # validate them when they are there.
        def email_required?
            false
        end

        def password_required?
            !self.password.nil? || !self.password_confirmation.nil?
        end

        # Devise uses this method to decide if email changed and
        # needs to be reconfirmed. We override it to prevent
        # normalization from being detected as a change.
        def postpone_email_change?
            self.normalized_email_changed? && super
        end

        def normalized_email_changed?
            before, after = self.changes['email']
            User.normalize_email(before) != User.normalize_email(after)
        end

        def confirmed?
            super && !self.email.nil?
        end

        def validatable?
            (!email.nil? || !unconfirmed_email.nil?) && (!password.nil? || !encrypted_password.nil?)
        end

        module ClassMethods
            def normalize_email(email)
                email.downcase.strip if email
            end

            def email_valid?(email)
                normalize_email(email) =~ EMAIL_REGEX
            end

            def email_registered?(email)
                where(email: normalize_email(email)).exists?
            end

            def email_available?(email)
                email_valid?(email) && !email_registered?(email)
            end
        end # ClassMethods
    end # Email
end
