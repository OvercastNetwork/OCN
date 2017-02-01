class Sale
    include Mongoid::Document
    store_in database: 'oc_sales'
    include FormattingHelper

    include EagerLoadable
    include RequestCacheable

    field :discount, type: Float
    field :start_at, type: Time
    field :stop_at, type: Time

    scope :active_at, -> (now = nil) {
        now ||= Time.now
        lte(start_at: now).gt(stop_at: now)
    }

    validates_presence_of :discount, :start_at, :stop_at

    cattr_cached :current do
        active_at.desc(:discount).first
    end

    def interval
        start_at .. stop_at
    end

    def active?(now = nil)
        interval.cover?(now || Time.now)
    end

    def discount_text
        "#{(discount * 100).round}% OFF"
    end

    def name
        "#{discount_text} from #{brief_date(start_at)} to #{brief_date(stop_at)}"
    end
end
