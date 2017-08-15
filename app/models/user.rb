require_dependencies 'user/*'

class User
    include Mongoid::Document
    include BackgroundIndexes

    store_in :database => "oc_users"

    # Would be nice if this could go in one of the modules below, but it doesn't work
    # because Devise modules don't use the ActiveSupport::Concern dependency mechanism.
    devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :confirmable, :validatable

    include Actions
    include Alerts
    include Alts
    include ApiModel
    include ApiSearchable
    include Big3Migration
    include Channels
    include Classes
    include Current
    include Engagements
    include Forums
    include Friendships
    include Git
    include Groups
    include Identity
    include LastSeen
    include Login
    include MinecraftPermissions
    include MinecraftRegistration
    include Nickname
    include OAuth
    include Perks
    include Premium
    include Profile
    include Punishments
    include PvpEncounters
    include Servers
    include Sessions
    include Settings
    include Skin
    include Stats
    include Teams
    include Teleporting
    include Tickets
    include TntLicense
    include TokenAuthenticatable
    include Tokens
    include Trophies
    include WebLogin
    include WebRegistration
end

# Force these models to load because they have belongs_to_legacy_user relations
# See User::Legacy::Macros for details
Death
Whisper
Participation
Session
