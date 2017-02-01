class FindRequest < ModelMessage
    field :skip
    field :limit

    def initialize(criteria: {}, model:, **opts)
        super model: model,
              payload: criteria,
              **opts
    end
end
