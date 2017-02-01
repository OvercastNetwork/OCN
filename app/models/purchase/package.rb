class Purchase
    class Package < Purchase

        purchase_name "Package"

        belongs_to :package, class_name: '::Package', allow_nil: false

        field :duration, type: Integer,
              validates: {numericality: {greater_than_or_equal_to: 0}, allow_nil: true}, # Some old transactions have duration = 0
              default: -> { default_duration }

        field :activated_at, type: Time

        attr_accessible :package, :activated_at

        before_save do
            self.activated_at ||= Time.now
        end

        def upgrade?
            price > 0
        end

        # Check that the purchase details match what is available in the shop
        # for the recipient right now. This may return false for past purchases
        # that are persisted, even though they are valid documents.
        def valid_now?
            if valid?
                package.available? or errors.add(:package, "is not public")
                duration == default_duration or errors.add(:duration, "does not match the expected value or #{default_duration}")
                duration.nil? || duration > 0 or errors.add(:duration, "must be non-zero")
                upgrade? or errors.add(:price, "is less than the user has already spent")

                super
            end
        end

        def default_duration
            package.duration - recipient.used_premium_time if !package.unlimited? && recipient?
        end

        def regular_price
            package.price.transform_if(recipient && recipient.highest_purchased_package) do |price, longest|
                price - longest.price
            end
        end

        def duration
            read_attribute(:duration).try(:seconds)
        end

        def days
            duration.in_days.round if duration
        end

        def duration_text
            if package.unlimited?
                "Unlimited"
            else
                d = days
                "#{d} #{"day".pluralize(d)}"
            end
        end

        def as_json(*)
            super.merge(
                id: package.id,
                name: package.name,
                time: (duration.to_i unless package.unlimited?), # JSON does not support infinity
                time_text: duration_text,
            )
        end

        def join_group!
            validate!
            recipient.join_group(package.group,
                                 start: activated_at,
                                 stop: (activated_at + duration unless package.unlimited?))
        end
    end
end
