# A layer on top of the DigitalOcean API for dealing with DNS records
class Zone

    class Record
        FIELDS = %i[id name type data ttl]
        attr_accessor :zone, *FIELDS

        def initialize(zone, values)
            @zone = zone
            FIELDS.each do |field|
                val = values[field] || values[field.to_s]
                instance_variable_set("@#{field}", val) if val
            end
        end

        def save!
            zone.update(self)
        end

        def backend
            DropletKit::DomainRecord.new(name: self.name, type: self.type, data: self.data, ttl: self.ttl)
        end

        def to_s
            vals = FIELDS.map{|field| "#{field}=#{send(field).inspect}"}
            "#<Zone::Record zone=#{self.zone} #{vals.join(' ')}>"
        end

        def inspect
            to_s
        end
    end

    class << self
        def cached(zone_name)
            @cache ||= {}
            @cache[zone_name] = new(zone_name) unless cache_hit = @cache[zone_name]

            if block_given?
                yield @cache[zone_name]
            else
                @cache[zone_name]
            end
        ensure
            @cache.delete(zone_name) unless cache_hit
        end
    end

    def initialize(zone_name)
        @zone_name = zone_name
        config = Rails.configuration.servers[:digitalocean]
        @client = DropletKit::Client.new(access_token: config[:access_token])
    end

    def update(record)
        if record.id
            @client.domain_records.update(record.backend, for_domain: @zone_name, id: record.id)
        else
            record.id = @client.domain_records.create(record.backend, for_domain: @zone_name).id
        end
    end

    def refresh
        @records = @client.domain_records.all(for_domain: @zone_name).map{|backend| Record.new(self, backend)}
    end

    def records
        @records or refresh
    end
end
