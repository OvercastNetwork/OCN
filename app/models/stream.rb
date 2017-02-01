class Stream
    include Mongoid::Document
    store_in :database => "oc_streams"

    field :channel,     type: String
    field :public,      type: Boolean
    field :priority,    type: Float
    field :event,       type: String
    field :type,        type: String, default: 'twitch'.freeze

    field :cached_info, type: Hash, default: {}.freeze
    field :cached_at, type: Time, default: Time::INF_PAST

    CACHE_TIMEOUT = 1.minute

    attr_accessible :channel, :public, :priority

    validates_presence_of :channel
    validates_presence_of :public
    validates_presence_of :priority

    index({priority: 1})
    index({channel: 1})
    index({public: 1})

    class << self
        def by_priority
            asc(:priority)
        end
    end

    def refresh_info!
        if type == 'twitch'
            self.cached_info = JSON.parse(open("https://api.twitch.tv/kraken/streams/#{channel}").read)
            self.cached_at = Time.now
            save!
        end
    rescue JSON::ParserError, OpenURI::HTTPError
        # ignore
    end

    def info
        if cached_at + CACHE_TIMEOUT < Time.now
            refresh_info!
        end
        cached_info
    end

    def live?
        info.key?('stream')
    end

    def status_text
        if (info = self.info) && (stream = info['stream'])
            stream['channel']['status']
        end
    end
end
