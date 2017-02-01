class ReportSearchRequest < FindRequest
    field :family_ids
    field :server_id
    field :user_id

    def initialize(criteria: {}, **opts)
        super criteria: criteria,
              model: Report,
              **opts
    end
end
