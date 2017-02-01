
# Call Server.update_dns on all bungees
# Log things to log/dns.log

Raven.capture

Rails.logger = logger = Logger.new('log/dns.log')
logger.formatter = -> (severity, datetime, progname, msg) do
    "[#{datetime} #{severity}] #{msg}\n"
end

def format_exception(ex)
    "#{ex.class.name}: #{ex.message}\n#{ex.backtrace.join("\n")}"
end

now = (Chronic.parse(ARGV[0]) if ARGV[0])

Rails.logger.info "Updating DNS#{" at #{now}" if now}"

Zone.cached(Rails.configuration.servers[:dns][:zone]) do
    Server.public_datacenters.each do |datacenter|
        # First, update disabled servers that can potentially be enabled. This minimizes
        # the chance of the minimum bungee limit preventing servers from being disabled
        # on their schedule.
        dns_disabled = Server.datacenter(datacenter).bungees.online.with_dns_record.dns_disabled.to_a
        dns_enabled = Server.datacenter(datacenter).dns_enabled.to_a

        [*dns_disabled, *dns_enabled].each do |server|
            begin
                server.apply_dns_schedule(now)
                if server.valid?
                    server.save
                else
                    messages = server.errors.flat_map{|_, msgs| msgs }
                    logger.warn "DNS update of #{server.name} not allowed:\n#{messages.map{|msg| "  #{msg}\n" }.join}"
                end
            rescue => ex
                logger.error "DNS update of #{server.name} raised:\n#{format_exception(ex)}"
                Raven.capture_exception(ex)
            end
        end
    end
end
