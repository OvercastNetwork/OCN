class User
    module Login
        extend ActiveSupport::Concern
        include Identity

        included do
            field :mc_sign_in_count, :default => 0
            field :mc_first_sign_in_at, type: Time, default: -> { Time.now.utc }
            alias_method :initial_join, :mc_first_sign_in_at
            field :mc_last_sign_in_at, :type => Time
            field :mc_last_sign_in_ip
            field :mc_ips, :type => Array, :default => -> { [] }
            field :mc_client_version, :type => String
            field :mc_locale, :type => String
            field :resource_pack_status, :type => String

            attr_accessible :resource_pack_status, :mc_client_version, :mc_locale

            api_property :mc_last_sign_in_ip, :mc_locale

            index({mc_first_sign_in_at: 1})
            index({mc_last_sign_in_at: 1})
            index({mc_ips: 1})

            after_save do
                if session = current_session
                    session.version = mc_client_version
                    session.save!
                end
            end
        end

        module Errors
            class Base < Exception; end

            # Mojang account has a bad username e.g. contains a space - we have seen this occasionally
            class BadUsername < Base; end

            # Could not find a matching user in offline mode
            class OfflineUserNotFound < Base; end

            class InvalidUuid < Base; end
        end

        module ClassMethods
            # Find a user with the given name and last IP, and an active account (uuid not nil)
            def for_offline_login(username, ip)
                where(
                    username_lower: username.downcase,
                    mc_last_sign_in_ip: ip,
                    :uuid.ne => nil
                ).first or raise Errors::OfflineUserNotFound
            end

            # Find or create a user for the given login credentials,
            # and update their username if a change is detected, but
            # don't save yet.
            #
            # If uuid is present, it is assumed that the arguments
            # have just been verified with Mojang i.e. through a
            # normal Bungee authentication.
            def for_login(uuid, username, ip)
                username =~ Identity::USERNAME_REGEX or raise Errors::BadUsername
                if uuid = normalize_uuid(uuid) and problem = uuid_invalid_reason(uuid)
                    raise Errors::InvalidUuid, problem
                end

                if uuid.nil?
                    for_offline_login(username, ip)
                else
                    uuid = normalize_uuid(uuid)
                    by_uuid(uuid) || User.new(uuid: uuid)
                end
            end

            # Try to login with the given credentials and return the
            # logged in User, with various fields updated and saved.
            #
            # It is assumed that the uuid and username have already
            # been verified with Mojang. In offline mode, the uuid
            # should be nil.
            #
            # A subclass of Errors::Base is raised for any failure.
            def login(uuid, username, ip, mc_client_version: nil)
                user = for_login(uuid, username, ip)

                user.claim_username!(username)

                user.mc_sign_in_count += 1
                user.mc_last_sign_in_at = Time.now.utc

                unless user.mc_ips.include?(ip) || IGNORED_NETS.any?{|net| net.matches?(ip) }
                    user.mc_last_sign_in_ip = ip
                    user.mc_ips << ip
                end

                user.mc_client_version = mc_client_version if mc_client_version

                user.skip_confirmation_notification!
                user.save!

                user
            end
        end
    end
end
