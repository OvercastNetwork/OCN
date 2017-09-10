class Server
    module Dns
        extend ActiveSupport::Concern

        included do
            # ID of this server's DNS record in DigitalOcean's API.
            field :dns_record_id, :type => Integer

            # True when this server currently has a public DNS record. The server must be
            # ready to accept connections whenever this flag is set.
            #
            # This field should only be changed by the enable_dns and disable_dns methods,
            # which are careful to keep it in sync with the actual state of the DNS
            # records, and to prevent DNS from being enabled when the server is offline
            # or a restart is queued.
            field :dns_enabled, :type => Boolean, :default => false

            # The time that the dns_enabled field last changed
            field :dns_toggled_at, :type => Time

            # True if this server should have DNS automatically enabled and disabled
            # according to the schedule below. If not true, the schedule will be
            # ignored and the DNS state will not be changed automatically, except to
            # disable it if the server is offline.
            #
            # The schedule is executed by calling update_dns, which checks this flag
            # and then calls either enable_dns or disable_dns based on the current time.
            field :dns_scheduled, :type => Boolean

            # Daily time window during which this server has DNS enabled, in seconds since
            # midnight UTC. If stop < start then DNS is enabled at the start/end of the day,
            # and disabled in the middle of the day.
            field :dns_window_start, :type => Integer
            field :dns_window_stop, :type => Integer

            attr_cloneable :dns_scheduled, :dns_window_start, :dns_window_stop

            scope :with_dns_record, where(:dns_record_id.ne => nil)

            # These scopes are based on the value of dns_enabled that is saved in the document
            scope :dns_enabled, where(dns_enabled: true)
            scope :dns_disabled, where(dns_enabled: false)

            # These scopes will actually do a DNS lookup to check if the server's IP is really resolvable
            scope :on_public_domain, ->(datacenter){ where(:ip.in => public_ips(datacenter)) }
            scope :off_public_domain, ->(datacenter){ where(:ip.not => {$in => public_ips(datacenter)}) }
            scope :in_public_datacenter, -> { where(:datacenter.in => public_datacenters) }

            api_property :dns_enabled, :dns_toggled_at

            validate do |server|
                if server.dns_enabled? || server.dns_scheduled?
                    server.bungee? or errors.add(:bungee, "only Bungees can use DNS")
                    server.ip or errors.add(:ip, "server requires an IP to use DNS")
                end

                if dns_change = server.changes['dns_enabled']
                    if !dns_change[0] && dns_change[1]
                        server.online? or errors.add(:dns_enabled, "DNS cannot be enabled while server is offline")
                        server.restart_queued_at and errors.add(:dns_enabled, "DNS cannot be enabled while server is queued to restart")
                    elsif dns_change[0] && !dns_change[1] && server.online? && !server.restart_queued_at
                        bungee_count = Server.datacenter(server.datacenter).dns_enabled.count
                        minimum_bungees = Rails.configuration.servers[:datacenters][server.datacenter][:minimum_bungees]
                        bungee_count <= minimum_bungees.to_i and errors.add(:dns_enabled, "DNS cannot be disabled because at least #{minimum_bungees} bungees must always be enabled")
                    end
                end

                if server.dns_scheduled?
                    [:dns_window_start, :dns_window_stop].each do |f|
                        (0...1.day).include?(server[f]) or errors.add(f, "must be within 0 to 24 hours")
                    end
                    server.dns_window_start == server.dns_window_stop and errors.add(:dns_window_start, "DNS schedule cannot start and stop at the same time")
                end
            end

            before_validation do
                self.dns_window_start = time_of_day(self.dns_window_start)
                self.dns_window_stop = time_of_day(self.dns_window_stop)
                self.dns_toggled_at = Time.now.utc if self.dns_enabled_changed?
                true
            end

            around_save :update_dns_record_on_save
        end

        module ClassMethods
            # Datacenters that have a DNS configuration
            def public_datacenters
                Rails.configuration.servers[:datacenters].keys
            end

            # The public domain used to connect to the given datacenter
            def public_domain(datacenter)
                zone = Rails.configuration.servers[:dns][:zone]
                "#{datacenter.downcase}"
            end

            # The internal domain used for the given datacenter and prefix
            def secret_domain(datacenter, prefix)
                prefix = Rails.configuration.servers[:dns][:"#{prefix}_prefix"]
                if prefix != nil
                    "#{prefix}.#{public_domain(datacenter)}"
                else
                    public_domain(datacenter)
                end
            end

            # DNS lookup all IPs on the given domain
            def get_ips(domain)
                Timeout.timeout(Rails.configuration.servers[:dns][:resolve_timeout]) do
                    Resolv.getaddresses(domain)
                end
            end

            def public_ips(datacenter)
                get_ips(public_domain(datacenter))
            end

            # Lookup the public DNS records for all datacenters and ensure the
            # dns_enabled field is in sync with the actual DNS state.
            def sync_dns_status
                public_datacenters.each do |datacenter|
                    ips = public_ips(datacenter)
                    self.datacenter(datacenter).where(:ip.in => ips, dns_enabled: false).update_all(dns_enabled: true, dns_toggled_at: Time.now.utc)
                    self.datacenter(datacenter).where(:ip.not => {$in => ips}, dns_enabled: true).update_all(dns_enabled: false, dns_toggled_at: Time.now.utc)
                end
            end
        end

        # Tests if this server's datacenter is listed in the server configuration.
        # This is used to avoid DNS lookups for junk datacenters, which will timeout.
        def in_public_datacenter?
            self.class.public_datacenters.include?(self.datacenter)
        end

        # The primary public domain used to connect to this server when
        # it is enabled, derived from the datacenter field e.g. "dc.some.network"
        def public_domain
            self.class.public_domain(self.datacenter) if self.in_public_datacenter?
        end

        # The "secret" domain that points to this server for a given
        # DNS state e.g. "live.dc.some.network"
        def secret_domain(prefix)
            self.class.secret_domain(self.datacenter, prefix) if self.in_public_datacenter?
        end

        # Test if the given domain has a record resolving to this server's IP
        def on_domain?(domain)
            self.class.get_ips(domain).include?(self.ip)
        end

        # Test if the public domain for this server's datacenter resolves to this server's IP
        def on_public_domain?
            domain = self.public_domain
            self.on_domain?(domain) if domain
        end

        # Get or create this server's DNS record from DigitalOcean's API as a Zone::Record object
        def dns_record
            if self.ip =~ Ipban::IP_REGEX
                zone = Zone.cached(Rails.configuration.servers[:dns][:zone])

                if self.dns_record_id
                    if rec = zone.records.find{|r| r.id == self.dns_record_id }
                        rec
                    else
                        Rails.logger.info "No DNS record for #{self.name} with id=#{self.dns_record_id}"
                    end
                end

                # Server has no DNS record yet, try to find one by IP or create a new one
                domains = [:disabled, :enabled].map{|prefix| self.secret_domain(prefix) }.compact

                if rec = zone.records.find{|r| self.ip == r.data && domains.include?(r.name) }
                    Rails.logger.info "Found matching DNS record id=#{rec.id} name=#{rec.name}"
                else
                    # Record still not found, make a new one (but don't save it)
                    Rails.logger.info "No DNS record found, creating a new one"
                    rec = Zone::Record.new(zone, {data: self.ip, type: 'A', ttl: Rails.configuration.servers[:dns][:ttl]})
                end

                self.dns_record_id = rec.id

                rec
            end
        end

        # Set the domain in this server's DNS record through DigitalOcean's API
        def set_domain(domain)
            rec = self.dns_record
            rec.name = domain
            rec.save!
            self.dns_record_id = rec.id if rec.id
            Rails.logger.info "Assigned #{self.datacenter} #{self.name} (#{self.ip}) to domain #{domain}"
        end

        # Set the ip in this server's DNS record through DigitalOcean's API
        def set_ip(ip)
            rec = self.dns_record
            rec.data = ip
            rec.save!
            self.dns_record_id = rec.id if rec.id
            Rails.logger.info "Assigned #{self.datacenter} #{self.name} to ip #{ip}"
        end

        # Applies DNS state changes when the document is saved. Disabling
        # happens before the save, and enabling happens after. This ensures
        # that DNS is never enabled when the document says it isn't.
        def update_dns_record_on_save
            if self.dns_record_id
                change = self.changes['ip']
                self.set_ip(self.ip) if change && self.ip
                toggle = self.changes['dns_enabled']
                self.set_domain(self.secret_domain(:disabled)) if toggle && !self.dns_enabled?
            end
            yield
        ensure
            # This should work in the case where DNS is being enabled, and also
            # in the case where DNS is being disabled but the save fails and it
            # needs to be re-enabled.
            self.set_domain(self.secret_domain(:enabled)) if toggle && self.dns_enabled?
        end

        # If given a Time or DateTime, extract the time-of-day after
        # converting to UTC. Any other value is returned unchanged.
        # This allows the dns_window_* fields to be set using
        # absolute times, as a convenience.
        def time_of_day(time)
            if time.respond_to?(:midnight)
                time = time.getutc
                time - time.midnight
            else
                time
            end
        end

        def dns_window_start=(time)
            self[:dns_window_start] = time_of_day(time)
        end

        def dns_window_stop=(time)
            self[:dns_window_stop] = time_of_day(time)
        end

        # True if public DNS should be enabled right now (or at the given time)
        # according to the scheduled DNS window.
        def in_dns_window?(time = nil)
            if self.dns_scheduled?
                time = (time || Time.now).utc
                time_of_day = time - time.beginning_of_day
                if self.dns_window_start <= self.dns_window_stop
                    self.dns_window_start <= time_of_day && time_of_day < self.dns_window_stop
                else
                    time_of_day < self.dns_window_stop || self.dns_window_start <= time_of_day
                end
            end
        end

        # Make any changes to this server's DNS record required by its state and/or schedule.
        # Does NOT save the document, which must be done to actually make changes to the DNS record.
        def apply_dns_schedule(time = nil)
            if self.dns_scheduled?
                time = (time || Time.now).utc
                if self.in_dns_window?(time)
                    unless self.dns_enabled?
                        Rails.logger.info "Enabling DNS for #{self.datacenter} #{self.name}"
                        self.dns_enabled = true
                    end
                else
                    if self.dns_enabled?
                        Rails.logger.info "Disabling DNS for #{self.datacenter} #{self.name}"
                        self.dns_enabled = false
                    end
                end
            end
        end
    end
end
