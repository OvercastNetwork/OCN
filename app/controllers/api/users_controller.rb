module Api
    class UsersController < ModelController
        controller_for User

        def by_username
            user = User.by_username(params[:username]) or raise NotFound
            respond(user.api_document)
        end

        # User search with a sender (nil sender is console)
        # Result includes current session and server if online
        def search
            sender = model_param(User, :sender_id) || User.console_user
            username = required_param(:username)
            user, matched_nick = User.by_username_or_nickname(username)
            raise NotFound unless user && user.uuid

            sighting = if matched_nick
                user.last_sighting
            else
                user.last_sighting_by(sender)
            end

            online = false
            session = server = nil

            if sighting.try!(:session).try!(:valid?)
                online = sighting.online?
                session = sighting.session
                server = sighting.server if !online || user.display_server_to?(sender)
            end

            respond(
                user: user.api_document,
                online: online,
                disguised: user.disguised_to?(sender),
                last_session: session.try!(:api_document),
                last_server: server.try!(:api_document)
            )
        end

        def by_uuid
            respond(player_ids_by_uuid: User.in(uuid: params[:uuids]).mash{|u| [u.uuid, u.api_player_id] })
        end

        def login
            @server = Server.find(params[:server_id])

            username = params[:username]
            uuid = params[:uuid]
            ip = params[:ip]
            virtual_host = params[:virtual_host]

            message = begin
                @user = User.login(uuid, username, ip, mc_client_version: params[:mc_client_version])
                nil
            rescue User::Login::Errors::BadUsername
                "Your username \"#{username}\" contains illegal characters.\n" +
                "Unfortunately, we cannot fix this.\n\n" +
                "Please contact Mojang and ask them to fix your account:\n" +
                ChatColor::AQUA + "https://help.mojang.com/customer/portal/emails/new"
            rescue User::Login::Errors::OfflineUserNotFound
                "Cannot login while Mojang session servers are offline"
            end

            message and return deny_login(:error, ChatColor::RED + message)

            if virtual_host =~ /\A(.*)\.register\./
                begin
                    @user.claim_register_token($1)
                    return deny_login(:error, "§e§lRegistration was §a§lSUCCESSFUL\n\n§9Now, go back to the §bwebsite§9 for the next step!")
                rescue User::RegisterError => e
                    return deny_login(:error, "§c#{e.message}")
                end
            end

            return deny_login(:error, @server.kick_message) if @server.kick_users

            route_to_server = nil

            if virtual_host.present?
                virtual_host_server = Server.find_by(:virtual_hosts => virtual_host)
                if virtual_host_server && virtual_host_server.family == 'private'
                    route_to_server = self.process_private_server_join(@user, virtual_host_server)
                    if route_to_server.nil?
                        return deny_login(:error, "Internal server error.\n\nPlease try again")
                    end
                end
            end

            # don't check punishments for private servers
            if route_to_server.nil?
                if Ipban.banned?(ip)
                    return deny_login(:banned, Punishment.mc_kick_message(reason: "Your IP: #{ip}", appeal: false))
                end
            end

            if route_to_server.nil? && (s = @user.server_commitment) && s.network == @server.network
                route_to_server = s.bungee_name
            end

            punishment = Punishment.current_ban(@user)
            session = unless punishment
                (Session.start!(server: @server, user: @user, ip: ip) if params[:start_session])
            end

            respond_to_login(route_to_server: route_to_server, punishment: punishment, session: session)
        end

        def logout
            model_instance
            respond
        end

        def credit_raindrops
            if user = model_instance.credit_raindrops(int_param(:raindrops))
                respond success: true,
                        user: user.api_document
            else
                respond success: false
            end
        end

        def purchase_gizmo
            group = Group.for_gizmo(params[:gizmo_name]).one or raise NotFound
            price = int_param(:price)

            if model_instance.purchase_gizmo(group, price)
                show
            else
                raise Forbidden, "user cannot purchase that gizmo"
            end
        end

        def credit_maptokens
            if user = model_instance.credit_maptokens(int_param(:maptokens))
                respond success: true,
                        user: user.api_document
            else
                respond success: false
            end
        end

        def credit_mutationtokens
            if user = model_instance.credit_mutationtokens(int_param(:mutationtokens))
                respond success: true,
                        user: user.api_document
            else
                respond success: false
            end
        end


        def update
            if attrs = params[:document]
                user = model_instance

                if attrs.key?('nickname')
                    user.set_nickname!(attrs.delete(:nickname))
                end

                # Synthetic property that is decoded into skin_url
                if blob = attrs.delete(:skin_blob)
                    user.skin_blob = blob
                end

                user.update_relations!(attrs)
                user.update_attributes!(attrs)

                after_update(user)
            end

            show
        rescue User::Nickname::Error => ex
            respond_with_message(BadNickname.new(problem: ex.problem, error: ex.message), status: 422)
        end

        def change_setting
            model_instance.change_setting!(required_param(:profile),
                                           required_param(:setting),
                                           params[:value])
            show
        end

        def change_class
            model_instance.change_class!(required_param(:category),
                                         params[:name])
            show
        end

        protected

        def lookup_model_instance
            # Allow lookup by player_id as well as _id
            User.by_player_id(params[:id]) || super
        end

        def deny_login(kick, message)
            respond_to_login(kick: kick, message: message)
        end

        def respond_to_login(kick: nil, message: nil, route_to_server: nil, punishment: nil, session: nil)
            respond(
                kick: kick,
                message: message,
                route_to_server: route_to_server,
                user: @user.try!(:api_document),
                session: session.try!(:api_document),
                punishment: punishment.try!(&:api_document),
                whispers: if @user then Whisper.deliverable_to(@user).map(&:api_document) else [] end,
                unread_appeal_count: if @user then Appeal::Alert.unread_by(@user).count else 0 end
            )
        end

        def process_private_server_join(user, server)
            # TODO: check whitelist
            pool_server = server.pool_server
            if pool_server.present?
                return pool_server.bungee_name
            else
                # need to start the server
                pool_server = Server.datacenter(server.datacenter)
                    .available_in_pool('private')
                    .find_one_and_update({$set => { server_definition: server.id }},
                                         return_document: :after)
                return nil if pool_server.nil?

                BaseWorker.publish(
                    {
                        server_id: server.id,
                        name: server.name,
                        settings: server.generate_settings,
                    },
                    type: 'reconfigure',
                    routing_key: pool_server.routing_key,
                    persistent: false,
                    mandatory: true,
                    expiration: 10.seconds
                )

                return pool_server.bungee_name
            end
        end
    end
end
