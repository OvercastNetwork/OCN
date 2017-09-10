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
        portal 'US' do
            long_name "America"
            hostname "us.#{ORG::DOMAIN}"
            listed? true
        end

        portal 'EU' do
            long_name "Europe"
            hostname "eu.#{ORG::DOMAIN}"
            listed? true
        end

        portal 'AU' do
            long_name "Australia"
            hostname "au.#{ORG::DOMAIN}"
            listed? true
        end

        portal 'DV' do
            long_name "Development"
            hostname "localhost"
            listed? false
        end
    end
end

