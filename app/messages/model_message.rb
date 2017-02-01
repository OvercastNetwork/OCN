class ModelMessage < BaseMessage
    header :model_name

    def initialize(model:, **opts)
        headers = {
            model_name: model.name
        }.merge(opts.delete(:headers).to_h)

        opts = {
            persistent: false,
            expiration: 1.minute,
            headers: headers,
        }.merge(opts)

        super(**opts)
    end

    def model
        @model ||= model_name.constantize
    end
end
