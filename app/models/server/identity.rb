class Server
    module Identity
        extend ActiveSupport::Concern
        include Connectivity
        include ApiModel
        include Cloneable

        # Network roughly corresponds to the public portal used to connect
        # to the server. Private servers will be on their own network, and
        # if we were to ever whore ourselves out to Youtubers who want their
        # own servers, those would be seperate networks as well. It can be
        # null for random junk servers that don't fit in anywhere.
        class Network < Enum
            create :PUBLIC, :PRIVATE, :TOURNAMENT
        end

        included do
            field :name, type: String
            field :description, type: String # translation key
            field :bungee_name, type: String
            field :priority, type: Integer, default: 0

            field :family, type: String
            belongs_to :family_obj, class_name: 'Family', foreign_key: :family
            scope :family, ->(family){ where(family: family) if family }
            scope :families, ->(families){ self.in(family: families.map(&:id)) if families }

            # Portal is the public domain used by the player to connect
            # (currently equivalent to datacenter)
            scope :portal, -> (portal) { self.where(datacenter: portal.id) }
            scope :portals, -> (portals) { self.in(datacenter: portals.map(&:id)) }

            field :network, type: Network
            scope :network, -> (network) { where(network: network) }

            attr_cloneable :priority, :family, :network, :description

            api_property :priority, :name, :description, :bungee_name, :family, :network

            validates_presence_of :priority
        end # included do

        module ClassMethods
            def by_name
                desc(:name)
            end

            def by_priority
                asc(:priority)
            end

            def find_by_name(name)
                q = where(name: /^#{Regexp.quote(name)}/i)
                q.first if q.count == 1
            end
        end # ClassMethods

        def portal
            Portal[datacenter]
        end

        def display_name(global: true)
            if global
                "#{name} (#{datacenter.upcase})"
            else
                name
            end
        end
    end # Identity
end
