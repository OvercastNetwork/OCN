# Sent by PGM servers configured for remote joining, at the moment they
# want to cycle to the next map. The API replies with a CycleResponse.
class CycleRequest < BaseMessage
    field :server_id
    field :map_id
    field :min_players
    field :max_players

    def server
        @server ||= Server.need(server_id)
    end
end
