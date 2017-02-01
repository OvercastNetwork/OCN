class Whisper
    include Mongoid::Document
    include BackgroundIndexes
    store_in database: 'oc_messages', collection: 'messages'

    include ApiAnnounceable
    include User::Legacy::Macros

    field :family, type: String
    belongs_to :server

    field :sent, type: Time
    field :delivered, type: Boolean, default: false
    field :content, type: String

    field :sender_nickname, type: String        # Sender nickname to show the receiver, or nil to show real name
    belongs_to_legacy_user relation: :sender,
                           external: :sender_uid,
                           internal: :sender_uid,
                           inverse_of: :messages_sent

    field :recipient_specified, type: String    # Recipient specified by sender when message was sent
    belongs_to_legacy_user relation: :recipient,
                           external: :recipient_uid,
                           internal: :recipient_uid,
                           inverse_of: :messages_received

    index(INDEX_sent = {sender_uid: 1, sent: -1})                           # Last sent
    index(INDEX_received = {recipient_uid: 1, sent: -1})                    # Last received
    index(INDEX_deliverable = {delivered: 1, recipient_uid: 1, sent: 1})    # Deliverable

    validates_presence_of :server_id, :sent, :content, :sender_uid, :recipient_uid
    validates_format_of :sender_nickname, with: User::USERNAME_REGEX, allow_nil: true

    props = [:_id, :family, :server_id, :sent, :delivered, :content,
             :sender_nickname, :recipient_specified]
    attr_accessible :sender_uid, :recipient_uid, *props
    api_property *props

    api_synthetic :sender_uid do
        sender.api_player_id
    end

    api_synthetic :recipient_uid do
        recipient.api_player_id
    end

    scope :deliverable_to, -> (user) {
        where!(recipient: user, delivered: false).hint(INDEX_deliverable).asc(:sent)
    }

    scope :sent_by, -> (user) {
        where!(sender: user).desc(:sent).hint(INDEX_sent)
    }

    scope :received_by, -> (user) {
        where!(recipient: user).desc(:sent).hint(INDEX_received)
    }

    class << self
        def for_reply(user)
            [sent_by(user).first, received_by(user).first].compact.max_by(&:sent)
        end
    end
end
