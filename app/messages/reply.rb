class Reply < BaseMessage

    field :success      # Success true/false
    field :error        # Optional error message

    alias_method :success?, :success

    def initialize(request: nil, success: true, error: nil, **opts)
        opts = {
            expiration: 1.minute,
            headers: {
                protocol_version: if request then request.protocol_version else ApiModel.protocol_version end
            }.merge(opts[:headers].to_h)
        }.merge(opts)

        super(payload: { success: success,
                         error: error }.merge(opts[:payload].to_h),
              in_reply_to: request,
              **opts)
    end
end
