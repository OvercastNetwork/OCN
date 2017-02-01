# Sent to PGM servers in reply to a CycleRequest. The server will send away
# any players listed in the destinations map before cycling, in a way that
# appears relatively seamless to the player.
class CycleResponse < Reply
    field :destinations

    def initialize(request = nil, destinations = {})
        if request
            super(
                request: request,
                success: true,
                payload: {
                    destinations: destinations.mash{|user, server| [user.uuid, server && server.id] }
                }
            )
        else
            super()
        end
    end
end
