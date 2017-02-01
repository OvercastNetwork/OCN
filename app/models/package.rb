class Package
    include Mongoid::Document
    store_in :database => "oc_packages"

    include EagerLoadable
    include Killable

    field :name, type: String, validates: {presence: true}
    field :description, type: String
    field :price, type: Integer, validates: {numericality: true}        # in cents
    field :time_limit, type: Integer                                    # seconds, nil if not timed
    field :priority, type: Integer, validates: {numericality: true}     # for ordering

    # management
    field :public, type: Boolean, default: true
    field :staging, type: Boolean, default: true

    belongs_to :group, class_name: 'Group'

    index_in_memory :group

    class << self
        def for_group(group)
            imap_where(group: group)
        end

        def available
            if PRODUCTION
                imap_all.where_attrs(public: true)
            else
                imap_all.where_attrs(staging: true)
            end
        end

        def purchases_by_id(recipient: nil, sale: nil, activated_at: Time.now)
            available.asc_by(&:price).map do |package|
                package.purchase(recipient: recipient, sale: sale, activated_at: activated_at)
            end.select(&:upgrade?).mash do |purchase|
                [purchase.package.id, purchase]
            end
        end
    end

    def available?
        if PRODUCTION
            public?
        else
            staging?
        end
    end

    def purchase(recipient: nil, sale: nil, activated_at: nil)
        Purchase::Package.new(package: self, recipient: recipient, sale: sale, activated_at: activated_at)
    end

    def time_limit
        read_attribute(:time_limit).try!(:seconds)
    end

    def duration
        (time_limit || Float::INFINITY).seconds
    end

    def unlimited?
        !time_limit?
    end
end
