class ServerSearchRequest < FindRequest
    field :datacenter
    field :network
    field :families
    field :offline
    field :unlisted

    def initialize(criteria: {}, **opts)
        super criteria: criteria,
              model: Server,
              **opts
    end

    def after_init
        self.model_name = Server.name
        super
    end
end
