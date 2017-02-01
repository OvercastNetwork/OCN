class DeathSearchRequest < FindRequest
	field :killer
	field :victim
	field :date

    def initialize(criteria: {}, **opts)
        super criteria: criteria,
              model: Death,
              **opts
    end
end
