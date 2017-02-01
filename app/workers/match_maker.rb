# A single-threaded worker that routes players to servers based on Game type
class MatchMaker
    include QueueWorker

    queue :match_maker
    consumer exclusive: true, manual_ack: false

    topic_binding SessionChange
    topic_binding ModelUpdate

    around_event :dequeue do |_, yielder|
        ApiSyncable.syncing(&yielder)
    end

    poll delay: 10.seconds do
        Ticket.expire!
    end

    handle PlayGameRequest do |request|
        ApiSyncable.syncing do
            if arena = request.arena
                arena.enqueue!(request.user)
            elsif ticket = request.user.ticket
                ticket.cancel!
            end
        end
    end

    handle SessionChange do |change|
        if ticket = change.user.ticket
            server = change.new_server
            if ticket.queued?
                # If player leaves the network while queued, remove them from the queue
                ticket.cancel! unless server
            elsif ticket.server == server
                # If player joins the server in their ticket, flag it as arrived (so it doesn't expire)
                ticket.arrive!
            elsif ticket.arrived?
                # If player leaves the server in their ticket, cancel it
                ticket.cancel!
            end
        end
    end

    handle CycleRequest do |request|
        # Whenever a server wants to cycle to the next map, check if it has enough players
        # for that map. If it doesn't, return new destinations for every player. The server
        # will send every player to a different server before cycling, or to the lobby if
        # they end up queued.

        server = request.server
        server.min_players = request.min_players
        server.max_players = request.max_players
        server.next_map_id = request.map_id
        server.save!

        if server.should_requeue?
            logger.info "Server #{server.bungee_name} will be emptied because it only has #{server.tickets.size}/#{request.min_players} players"
            tickets = server.requeue_participants!
            CycleResponse.new(request, tickets.mash do |ticket|
                [ticket.user, ticket.server]
            end)
        else
            logger.info "Server #{server.bungee_name} is cycling"
            CycleResponse.new(request)
        end
    end

    handle ModelUpdate do |msg|
        if msg.model <= Server
            server = msg.document
            server.arena.process_queue! if server.game?
        end
    end
end
