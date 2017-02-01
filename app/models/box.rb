class Box
    include MiniModel

    field :datacenter
    field :workers      # Array of worker classes
    field :services     # Array of symbols used to enable special behavior in particular boxes
    field :hostname

    def services
        @services ||= []
    end

    def hostname
        @hostname ||= "#{id}.lan"
    end

    def routing_key
        "box.#{id}"
    end

    class << self
        def local_id
            ENV['OCN_BOX'] || Socket.gethostname.partition(/\./).first
        end

        def local
            find_or_create(local_id)
        end

        # HACK
        def valid?(box_id, datacenter)
            if box_id =~ /^chi/
                ['US', 'TM', 'DV'].include? datacenter
            elsif box_id =~ /^ams/
                'EU' == datacenter
            else
                # Probably dev environment, so just let it slide
                true
            end
        end
    end
end
