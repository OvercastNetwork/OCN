class Portal
    include MiniModel

    field :long_name
    field :hostname
    field :listed?

    alias_method :short_name, :id

    def to_param
        id.downcase
    end

    def servers
        Server.portal(self)
    end

    class << self
        def listed
            select(&:listed?)
        end
    end

    define do
        portal 'DC' do
            long_name "Global"
            hostname "dc.#{ORG::DOMAIN}"
            listed? true
        end

        portal 'DV' do
            long_name "Development"
            hostname "localhost"
            listed? false
        end
    end
end

