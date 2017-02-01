class PingMessage < BaseMessage
    field :reply_with # 'success', 'failure', 'exception'

    def initialize(reply_with: 'success', **opts)
        opts[:expiration] ||= 30.seconds
        super(payload: {reply_with: reply_with}, **opts)
    end
end
