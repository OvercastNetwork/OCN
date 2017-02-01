class Family
    include Mongoid::Document
    store_in :database => "oc_families"

    include Killable
    include Buildable
    include EagerLoadable

    field :name, type: String
    field :priority, type: Integer
    field :public, type: Boolean

    props = [:name, :priority, :public]
    attr_accessible :_id, *props
    attr_buildable *props

    validates *props, presence: true

    def joined_servers
        @joined_servers ||= []
    end

    class << self
        def left_join_servers(servers)
            families = all.to_a
            families_by_id = families.index_by(&:id)

            servers = servers.families(families) if servers.respond_to?(:families)

            servers.each do |server|
                if family = families_by_id[server.family]
                    family.joined_servers << server
                end
            end

            families
        end

    	def by_priority
    		imap_all.asc_by(&:priority)
    	end

        def only_public
            imap_all.select(&:public?)
        end
    end
end
