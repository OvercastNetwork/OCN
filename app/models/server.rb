require_dependencies 'server/*'

class Server
    include Mongoid::Document
    include Mongoid::Timestamps

    DATABASE_NAME = "oc_servers"
    store_in :database => DATABASE_NAME

    include Killable
    default_scope -> { alive }

    include Cloneable

    include Amqp
    include ApiModel
    include Bungees
    include Connectivity
    include Deployment
    include Dns
    include Dynamics
    include Ensure
    include Games
    include Identity
    include Lifecycle
    include Maps
    include Matches
    include Operators
    include MinecraftPermissions
    include PlayerCounts
    include PublicVisibility
    include ResourcePacks
    include Restart
    include Roles
    include Rotations
    include Search
    include Serialization
    include Sessions
    include Settings
    include Tournaments
    include UpgradeWarning
    include Virtualization
    include Whitelist
    include Mutation
end
