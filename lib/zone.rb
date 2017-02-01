
# A layer on top of the Cloudflare API for dealing with DNS records
class Zone
    class Error < Exception
    end

    class Record
        FIELDS = %i[zone_name rec_id name type content ttl service_mode]
        attr_accessor :zone, *FIELDS

        def initialize(zone, vals)
            @zone = zone
            FIELDS.each do |field|
                val = vals[field] || vals[field.to_s]
                instance_variable_set("@#{field}", val) if val
            end
            self.service_mode = [true, 1, '1'].include?(self.service_mode)
        end

        def save
            if %w(production staging).include? Rails.env
                if self.rec_id
                    self.zone.req(:rec_edit, self.zone_name, self.type, self.rec_id, self.name, self.content, self.ttl, self.service_mode, 0)
                else
                    res = self.zone.req(:rec_new, self.zone_name, self.type, self.name, self.content, self.ttl, 0)
                    self.rec_id = res['rec']['obj']['rec_id']
                    res
                end
            else
                Rails.logger.info ">>> Record.save rec_id=#{rec_id} zone_name=#{zone_name} name=#{name} type=#{type} content=#{content} ttl=#{ttl}"
            end
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
        config = Rails.configuration.servers[:cloudflare]
        @cloudflare = CloudFlare.connection(config[:api_key], config[:email])
    end

    def req(meth, *args)
        r = @cloudflare.send(meth, *args)
        raise Error r['message'] unless r['result'] == 'success'
        r['response']
    end

    def build_record(args = {})
        Record.new(self, args.merge(zone_name: @zone_name))
    end

    def refresh
        has_more = true
        offset = 0
        records = []
        while has_more
            res = req(:rec_load_all, @zone_name, offset)
            has_more = res['recs']['has_more']
            offset += res['recs']['count']
            records += res['recs']['objs'].map{|rec| Record.new(self, rec) }
        end
        @records = records
    end

    def records
        @records or refresh
    end
end
