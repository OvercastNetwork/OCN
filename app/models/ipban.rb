class Ipban
    include Mongoid::Document
    include BackgroundIndexes
    store_in :database => "oc_ipbans"

    field :ip, type: String
    field :to, type: String
    field :mask, type: String
    field :description, type: String
    field :blocked, type: Integer, default: 0

    index({ip: 1}, {unique: true})

    IP_REGEX = /\A\d+\.\d+\.\d+\.\d+\z/
    validates_format_of :ip, with: IP_REGEX, allow_nil: false
    validates_format_of :to, with: IP_REGEX, allow_nil: true
    validates_format_of :mask, with: IP_REGEX, allow_nil: true

    class << self
        def parse(ip)
            ip.split('.').map(&:to_i).reduce(0) do |n, c|
                (n << 8) | c
            end
        end

        def banned?(ip)
            answer = false
            each do |ban|
                if ban.matches?(ip)
                    answer = true
                    ban.inc(blocked: 1)
                end
            end
            answer
        end
    end

    def matches?(ip)
        if ip =~ Ipban::IP_REGEX
            ip = Ipban.parse(ip)

            lower = Ipban.parse(self.ip)
            upper = self.to ? Ipban.parse(self.to) : lower

            if self.mask
                mask = Ipban.parse(self.mask)
                ip &= mask
                lower &= mask
                upper &= mask
            end

            ip >= lower && ip <= upper
        end
    end
end
