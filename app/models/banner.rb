class Banner
    include Mongoid::Document
    include Mongoid::Timestamps
    include EagerLoadable
    store_in :database => "oc_banners"

    field :text, type: String, validates: {presence: true}
    field :active, type: Boolean, default: false, validates: {presence: true}
    field :weight, type: Float, default: 1.0, validates: {presence: true}
    field :expires_at, type: Time, validates: {presence: true}

    scope :active, -> { where(active: true).gt(expires_at: Time.now) }

    attr_accessible :text, :active, :weight, :expires_at

    before_save do
        render('US') # Ensure this works before saving
    end

    after_save do
        Server.bungees.online.each(&:api_sync!)
    end

    TITLE = "§b§lStratus Network"
    PIXELS = 263

    class << self
        def active
            now = Time.now
            imap_all.select do |banner|
                banner.active_at(time: now)
            end
        end

        def make_motd_top(text)
            ChatUtils.padded_heading("╔", text, "╗", width: PIXELS, pad: "═", pad_color: ChatColor::BLUE)
        end

        def make_motd_bottom(text)
            ChatUtils.padded_heading("╚", text, "╝", width: PIXELS, pad: "═", pad_color: ChatColor::BLUE)
        end

        def make_motd(datacenter:, title: TITLE, message: nil)
            top = make_motd_top(title)
            bottom = if message
                         make_motd_bottom(message)
                     else
                         "§9╚#{ "═" * 28 }╝" # Must increase PIXELS to 269 if we ever want this
                     end
            [top, bottom].join("\n")
        end
    end

    def render(datacenter)
        self.class.make_motd(datacenter: datacenter.to_s.upcase, message: self.text)
    end

    def active_at(time: nil)
        active? && expires_at > (time || Time.now)
    end

    def expires?
        expires_at != Time::INF_FUTURE
    end

end
