class BaseTask < BaseMessage
    def initialize(worker: nil, **opts)
        super(**{
            routing_key: (worker || TaskWorker).queue_name,
            expiration: 1.minute
        }.merge(opts))
    end

    def call
        raise NotImplementedError
    end
end
