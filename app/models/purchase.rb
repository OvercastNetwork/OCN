
# A document that represents the purchase of a single item. It identifies what was
# purchased, who it was delivered to, the price that was payed, and any discounts
# that were applied. It is passed around to communicate available purchases, and
# also embedded in a Transaction document when the purchase is actually made.
#
# The base class is abstract, and is subclassed to implement particular types of purchases.

class Purchase
    include Mongoid::Document
    embedded_in :transaction

    belongs_to :sale

    belongs_to :recipient,
               foreign_key: :user_id,
               class_name: 'User',
               allow_nil: false,
               validates: {real_user: true}

    field :price,
          type: Integer,
          validates: {numericality: {greater_than_or_equal_to: 0}}, # Some old transactions have price = 0
          default: -> { default_price }

    attr_accessible :recipient, :sale

    class << self
        def purchase_name(n = nil)
            @purchase_name = n if n
            @purchase_name
        end
    end

    delegate :purchase_name, to: :class

    def initialize(attrs = {})
        attrs[:sale] ||= Sale.current
        attrs[:recipient] ||= User.current
        super(attrs)
    end

    # Check that the purchase details match what is available in the shop
    # for the recipient right now. This may return false for past purchases
    # that are persisted, even though they are valid documents.
    def valid_now?
        if valid?
            sale and (sale.active? or errors.add(:sale, "is not currently active"))
            price == default_price or errors.add(:price, "does not have the expected value of #{default_price}")
            price > 0 or errors.add(:price, "must be non-zero")

            errors.empty?
        end
    end

    def regular_price
        raise NotImplementedError
    end

    def discount
        sale.try!(:discount) || 0
    end

    def discount_text
        sale.try!(:discount_text)
    end

    def default_price
        (regular_price * (1 - discount)).round
    end

    def regular_price_text
        "$#{FormattingHelper.format_dollars(cents: regular_price)}"
    end

    def price_text
        "$#{FormattingHelper.format_dollars(cents: price)}"
    end

    def as_json(*)
        {
            regular_price: regular_price,
            regular_price_text: regular_price_text,
            price: price,
            price_text: price_text,
            discount: discount,
            discount_text: discount_text,
        }
    end
end

require_dependencies 'purchase/*'
