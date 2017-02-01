class EngagementUpdateRequest < BaseMessage
    field :engagements

    def initialize(engagements = nil, **opts)
        opts = {
            routing_key: 'engagements',
            persistent: true
        }.merge(opts)

        super(payload: {engagements: engagements}, **opts)
    end
end
