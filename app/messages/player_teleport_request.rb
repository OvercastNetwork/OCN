class PlayerTeleportRequest < BaseMessage
    field :player_uuid
    field :target_server
    field :target_player_uuid

    def initialize(player = nil, target_user: nil, target_server: nil, **opts)
        if player
            opts = {
                persistent: false,
                expiration: 10.seconds,
                routing_key: 'teleport'
            }.merge(opts)

            target_server ||= target_user.current_server if target_user

            super(payload: {
                player_uuid: player.uuid,
                target_server: target_server && {
                    _id: target_server.id,
                    datacenter: target_server.datacenter,
                    name: target_server.name,
                    bungee_name: target_server.bungee_name,
                    priority: target_server.priority
                },
                target_player_uuid: target_user && target_user.uuid
            }, **opts)
        else
            super()
        end
    end
end
