# Notification of a player finishing and/or starting a session.
# Either of old_session or new_session can be nil, but not both.
#
#     - Connect to network: old_session = nil, new_session != nil
#     - Disconnect from network: old_session != nil, new_session = nil
#     - Change server or nickname: old_session != nil, new_session != nil
#
# This message originates from the API controller that handles
# session requests from servers, not from the servers themselves.

class SessionChange < BaseMessage
    field :old_session
    field :new_session

    def initialize(old_session: nil, new_session: nil, **opts)
        if old_session || new_session
            opts = {
                persistent: false,
                expiration: 1.minute,
            }.merge(opts)

            super(payload: {
                old_session: old_session.try!(:api_document),
                new_session: new_session.try!(:api_document),
            }, **opts)
        else
            super()
        end
    end

    def old_session
        json = payload[:old_session] and @old_session ||= Session.find(json['_id'])
    end

    def new_session
        json = payload[:new_session] and @new_session ||= Session.find(json['_id'])
    end

    def new_server
        @new_server ||= (s = new_session and s.server)
    end

    def user
        User.need((payload[:old_session] || payload[:new_session])['user'][2])
    end
end
