class PunishmentSearchRequest < FindRequest
	field :punisher
	field :punished
	field :active

    def initialize(criteria: {}, **opts)
        super criteria: criteria,
              model: Punishment,
              **opts
    end
end
