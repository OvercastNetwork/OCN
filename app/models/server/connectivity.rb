class Server
    module Connectivity
        extend ActiveSupport::Concern
        include Lifecycle

        included do
            # Datacenter where the server is hosted
            field :datacenter, type: String
            scope :datacenter, ->(datacenter){ where(datacenter: datacenter.upcase) if datacenter }

            # Box the server is running on
            field :box, as: :box_id, type: String
            scope :box, -> (box) { where(box: (if box.is_a?(Box) then box.id else box end)) }

            # IP or hostname that should be used to connect to the server
            # For Bungees, this is a public routable IP. For servers behind
            # the proxy, this is an internal hostname like "chi01.lan".
            field :ip, type: String
            attr_accessible :ip

            # Explicit port set in the server control panel. If this is nil,
            # the server will allocate a port dynamically on startup and report
            # it back to the API.
            field :port, :type => Integer

            # If the server is online, this is the port it is currently listening on,
            # which may be statically assigned or dynamically allocated.
            field :current_port, type: Integer
            attr_accessible :current_port

            attr_cloneable :datacenter

            api_property :datacenter, :ip, :current_port
            api_synthetic :box, :box_id   # TODO: rename the Java field

            api_synthetic :domain do
                connect_to
            end

            before_event :startup do
                self.current_port = current_port.to_i
                self.current_port = port if current_port == 0
                true
            end

            before_validation do
                self.port = nil if self.port == 0
                true
            end

            validates_each :box_id do |server, attr, value|
                unless Box.valid?(value, server.datacenter)
                    server.errors.add attr, "is not in datacenter #{server.datacenter}"
                end
            end
        end # included do

        module ClassMethods
            def by_datacenter
                asc(:datacenter)
            end
        end # ClassMethods

        def ip
            attributes['ip'] || (box_obj && box_obj.hostname)
        end

        def box_obj
            Box.find_or_create(box_id) if box_id
        end

        def connect_to
            "#{datacenter.downcase}.#{Rails.configuration.servers[:dns][:zone]}"
        end
    end # Connectivity
end
