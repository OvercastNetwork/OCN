
# A report of player activity on a PGM server, along with the map being played
class ServerPlayerReport < BaseMessage
    include ServerReport

    prefix 'players'

    field :map_id

    metric :players
    metric :participants
    metric :observers
    metric :joins
    metric :leaves

    def datadog_tags
        [*super, "map_id:#{map_id}"]
    end
end
