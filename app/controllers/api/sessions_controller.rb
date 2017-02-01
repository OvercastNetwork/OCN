module Api
    class SessionsController < ModelController
        controller_for Session

        def start
            user = player_param
            server = model_param(Server, :server_id)
            old_session = model_param(Session, :previous_session_id, required: false)

            session = Session.start!(server: server, user: user, ip: params[:ip], old_session: old_session)

            respond(session.api_document)
        end

        def finish
            # Note that this endpoint only has an effect when the player is disconnecting
            # from the network.
            #
            # When changing servers, the player's old session will *always* be finished
            # by logging into the new server, which happens before the old server hits
            # this endpoint.
            #
            # When changing nicknames, the server passes the old session explicitly,
            # and does not call this endpoint at all.
            #
            # We rely on this in order to fire the correct SessionChange message.

            model_instance.finish!
            respond(model_instance.api_document)
        end

        def online
            if session = Session.last_online_started_by(player_param) and session.valid?
                respond(session.api_document)
            else
                raise NotFound
            end
        end

        def friends
            documents = player_param.friends.map do |friend|
                Session.last_started_by(friend)
            end.compact.select(&:valid?).sort_by(&:start).reverse
            respond_with_message FindMultiResponse.new(model: Session, documents: documents)
        end

        protected

        def model_criteria
            sessions = super

            if family_ids = params[:family_ids]
                sessions = sessions.families([*Family.imap_find(*family_ids.to_a)])
            end

            if network = enum_param(Server::Network)
                sessions = sessions.network(network)
            end

            if boolean_param(:staff)
                sessions = sessions.staff
            end

            if boolean_param(:online)
                sessions = sessions.online
            end

            unless boolean_param(:disguised, default: true)
                sessions = sessions.undisguised
            end

            # Should never exceed 1000
            sessions.desc(:start).limit(1000).prefetch(:player).select{|s| s.player }
        end
    end
end
