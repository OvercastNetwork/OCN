class User
    # User elements related to identity and in-game login
    module Identity
        extend ActiveSupport::Concern

        USERNAME_REGEX = /\A([a-zA-Z0-9_]{1,16}|[0-9a-f]{24})\z/
        USERNAME_NORMALIZED_REGEX = /\A([a-z0-9_]{1,16}|[0-9a-f]{24})\z/
        UUID_REGEX = /\A[0-9a-f]{32}\z/
        PLAYER_ID_REGEX = /\A([a-zA-Z0-9_ ]{1,16}|_[0-9a-f]{24})\z/ # some old usernames have spaces

        class MojangUuidValidator < ActiveModel::EachValidator
            def validate_each(user, attr, uuid)
                if uuid !~ UUID_REGEX
                    user.errors.add(attr, "is not a valid UUID")
                else
                    v = UUIDTools::UUID.parse_hexdigest(uuid).version
                    v == 4 or user.errors.add(attr, "must be version 4 (was version #{v})")
                end
            end
        end

        class Username
            include Mongoid::Document
            include Mongoid::Timestamps::Created
            embedded_in :user

            field :exact, type: String
            field :canonical, type: String

            attr_accessible :exact, :created_at

            validates_format_of :exact, with: USERNAME_REGEX
            validates_format_of :canonical, with: USERNAME_NORMALIZED_REGEX

            after_initialize :canonicalize
            before_validation :canonicalize

            def canonicalize
                self.canonical = User.normalize_username(exact)
            end
        end

        # An error while updating or verifying a username with Mojang
        class UsernameError < Exception; end

        included do
            # Mojang's UUID (nil means account could not be verified with Mojang)
            field :uuid

            # OCN's legacy ID used in a few large collections.
            # This needs to NOT look like an ObjectId, otherwise Mongoid
            # will try to coerce it into one in various situations.
            field :player_id, type: String, default: -> { "_#{id}" }

            # The user's current, verified username. The default is a
            # placeholder until their username is first verified.
            field :username #, default: -> { id.to_s }
            field :username_lower

            embeds_many :usernames, class_name: 'User::Identity::Username'

            # Last time the current username was verified with Mojang.
            # If nil, the current username is not verified, which
            # happens when a different user has been verified to
            # own it.
            field :username_verified_at, type: DateTime

            # If set, simulate a username change
            field :fake_username, :type => String

            # Email addresses used to identify the user on external services.
            # Only trusted staff have access to this. Note that the primary
            # email is NOT necessarily in this list, because this may be an
            # alternate account, and the user may want to use this account's
            # email in the external list of a different account (and yes,
            # this has actually happened).
            field :external_emails, type: Array, default: [].freeze
            attr_accessible :external_emails, as: :user
            unset_if_blank(:external_emails)

            before_validation do
                self.external_emails = self.external_emails.reject(&:blank?).map(&:strip).uniq
            end

            validates_each :external_emails, if: :external_emails_changed? do |record, attr, emails|
                emails.each do |email|
                    if user = User.by_external_email(email) and user != self
                        record.errors.add(attr, "contains #{email} that already belongs to #{user.username}")
                    end
                end
            end

            properties = [:username, :uuid, :player_id]
            attr_accessible *properties
            api_property *properties
            api_synthetic :player, :api_player_id

            index({uuid: 1},                {unique: true, sparse: true})
            index({player_id: 1},           {unique: true})

            index({username: 1},            {unique: true, sparse: true})
            index({username_lower: 1},      {unique: true, sparse: true})
            index({username_verified_at: 1})
            index({fake_username: 1},       {sparse: true})

            index(INDEX_external_emails = {external_emails: 1}, {unique: true, sparse: true})

            index({'usernames.created_at' => 1})
            index({'usernames.exact' => 1})
            index({'usernames.canonical' => 1})

            validates_presence_of :player_id
            validates_presence_of :username
            validates_format_of :username,          with: USERNAME_REGEX,               if: :username_verified?
            validates_format_of :username_lower,    with: USERNAME_NORMALIZED_REGEX,    if: :username_verified?
            validates           :uuid,              mojang_uuid: true, allow_nil: true
            validates_format_of :player_id,         with: PLAYER_ID_REGEX

            after_initialize    :normalize_identity_fields
            before_validation   :normalize_identity_fields
            before_save         :normalize_identity_fields
        end

        module ClassMethods
            def normalize_username(username)
                username.strip.downcase if username
            end

            def find_by_username(username)
                self.find_by(username_lower: normalize_username(username))
            end

            def by_username(username)
                where(username_lower: normalize_username(username)).one if username
            end

            def by_past_username(username)
                by_username(username) || with_past_username(username).one_or_nil
            end

            def with_past_username(username)
                where('usernames.canonical' => normalize_username(username))
            end

            def normalize_uuid(uuid)
                if uuid.is_a? UUIDTools::UUID
                    uuid.hexdigest
                elsif uuid
                    uuid.gsub(/-/,'').downcase
                end
            end

            def uuid_invalid_reason(uuid)
                unless UUIDTools::UUID.parse_hexdigest(uuid).version == 4
                    "Not a v4 UUID (probably generated for an offline login)"
                end
            end

            def by_uuid(uuid)
                User.where(:uuid => normalize_uuid(uuid)).one if uuid
            end

            def by_player_id(id)
                User.where(:player_id => id).one if id
            end

            def by_username_or_id(username_or_id)
                by_username(username_or_id) || by_uuid(username_or_id) || by_player_id(username_or_id)
            end

            def by_external_email(email)
                where(external_emails: email).hint(INDEX_external_emails).first
            end

            def by_external_emails(*emails)
                self.in(external_emails: emails).hint(INDEX_external_emails)
            end
        end

        def username_verified?
            !!username_verified_at
        end

        def has_username?(username)
            username_verified? && self.username_lower == User.normalize_username(username)
        end

        def has_uuid?(uuid)
            self.uuid == User.normalize_uuid(uuid)
        end

        def uuid_obj
            UUIDTools::UUID.parse_hexdigest(self.uuid)
        end

        # The API client can deserialize this into a tc.oc.api.PlayerId
        def api_player_id
            [self.player_id, self.username, self.id.to_s]
        end

        def permalink
            "https://#{ORG::DOMAIN}/#{uuid}"
        end

        def to_s
            self.username
        end

        def normalize_identity_fields
            self.uuid = User.normalize_uuid(self.uuid) if self.uuid

            if self.username
                self.username.strip!
                self.username_lower = User.normalize_username(self.username)
            else
                self.username_lower = nil
            end
        end

        # Set this User's name to the given (verified) username, and return self.
        # This should be called whenever the name has been verified with Mojang.
        # Any conflicting usernames will be refreshed from the Mojang API and
        # claimed recursively.
        def claim_username!(claimed_name, visited: [])
            if visited.include?(self)
                # This should be impossible since we clear the username before recursing
                raise UsernameError, "Cycle detected while claiming username #{claimed_name.inspect} for user #{uuid}: #{visited.map(&:uuid).join(" -> ")}"
            end

            normalize_identity_fields

            # Presumably, usernames can be changed without changing the canonical form
            # i.e. only changing the case. So, we need to check for an exact match here.
            if username != claimed_name
                Logging.logger.info "Username change from #{username.inspect} to #{claimed_name.inspect} for #{uuid}"

                # Check if the new name is already in use by a different user
                if (other = User.by_username(claimed_name)) && other != self
                    # First, clear this user's name since we know it's invalid, and
                    # it is at least conceivable that the conflicting user, or some
                    # other user in the chain, will claim this user's old name.
                    clear_username! if username

                    # Refresh the other user's name. If the refresh
                    # fails for whatever reason, they will be left
                    # with no username until the next time they login.
                    other.refresh_username!(visited: [*visited, self])

                    # Verify that the conflict has been resolved. If it hasn't,
                    # our code is broken or Mojang's API is crazy.
                    if other = User.by_username(claimed_name)
                        raise UsernameError, "Username #{claimed_name.inspect} cannot be claimed by #{uuid} because it already belongs to #{other.uuid}"
                    end
                end

                # Give the user their new name and add it to their history
                set_username!(claimed_name)
            end

            self.username_verified_at = DateTime.now if username == claimed_name

            self
        end

        # Username given to this user when their actual name is unavailable
        def fallback_username
            id.to_s
        end

        # Clear this user's name and give them a temporary one based on their _id
        def clear_username!
            self.username = fallback_username
            self.username_verified_at = nil
            save!
        end

        # Set a new username for this user, and add it to their history
        def set_username!(new_name)
            Logging.logger.info "Setting username #{new_name.inspect} for #{uuid}"
            self.username = new_name
            self.username_verified_at = DateTime.now
            unless !usernames.empty? && usernames.last.exact == new_name
                self.usernames << Username.new(exact: new_name, created_at: Time.now) # Automatic created_at does not seem to work
            end
            save!
        end

        # Lookup this user's current name from Mojang and claim it.
        def refresh_username!(visited: [])
            if uuid
                if fake_username
                    # If a fake username is set, claim it
                    Logging.logger.info "Faking username to #{fake_username.inspect} for #{uuid}"
                    claim_username!(fake_username, visited: visited)
                else
                    # Fetch the current username for this user's UUID from Mojang,
                    # then verify it using a reverse lookup. If the reverse lookup
                    # returns a different UUID, it probably means this account was
                    # deactivated, and another account took the name. This has happened
                    # before, and the profile data from the old account does not
                    # indicate that it is deleted in any way.
                    Logging.logger.info "Fetching username for #{uuid}"
                    name = Mojang::Profile.from_uuid(uuid).name
                    name_uuid = User.normalize_uuid(Mojang.username_to_uuid(name))
                    if uuid == name_uuid
                        claim_username!(name, visited: visited)
                    else
                        Logging.logger.info "Clearing username for #{uuid} because their current username #{name.inspect} resolves to #{name_uuid}"
                        clear_username!
                    end
                end
            else
                Logging.logger.info "Clearing username for user with _id=#{id} because they have no UUID"
                clear_username!
            end
        rescue Mojang::Error
            raise UsernameError, "Mojang API error while refreshing username for #{uuid}"
        end
    end
end
