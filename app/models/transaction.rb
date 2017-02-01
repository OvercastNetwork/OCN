require_dependencies 'transaction/*'

class Transaction
    include Mongoid::Document
    include Mongoid::Timestamps
    store_in :database => "oc_transactions"

    field :total, default: 0, type: Integer, allow_nil: false
    field :description, :default => "".freeze
    field :note
    field :ip
    belongs_to :user

    module Status
        MAP = {
            UNPAYED: 0,   # Payment in progress or unhandled error while processing payment
            PAYED: 1,     # Payment succeeded
            DECLINED: 2,  # Payment failed
            INVALID: 3,   # Purchase was not valid when processing started
            REFUNDED: 4   # Payment refunded
        }
        MAP.each{|k, v| const_set(k, v) }
    end
    field :status, type: Integer, default: Status::UNPAYED, allow_nil: false

    # emails
    field :email, type: String
    field :email_sent, type: Boolean

    class Error < Exception; end

    embeds_one :purchase, store_as: 'package', class_name: 'Purchase'

    # Providers (legacy)
    field :paypal, default: {}.freeze # {token, payer_id, transaction_id}
    field :google, default: {}.freeze # {token, order_number}

    # TODO: move the other providers to this field, if we ever use them again
    embeds_one :processor, class_name: 'Transaction::Processor'

    attr_accessible :total, :description, :status, :note, :ip,
                    :email, :email_sent, :user, :user_id,
                    :package, :paypal, :google, :processor

    scope :package, -> (package) { where('package.id' => package.id) }
    scope :recipient, -> (user) { where('package.user_id' => user.id) }
    scope :buyer, -> (user) { where(user: user) }

    scope :unpayed, where(status: Status::UNPAYED)
    scope :payed, where(status: Status::PAYED)
    scope :declined, where(status: Status::DECLINED)

    class << self
        def by_date
            desc(:created_at)
        end

        def new_package_purchase(package:, price:, recipient:, buyer:, ip:, processor:)
            new(
                total: price,
                description: package.name,
                ip: ip,
                user: buyer,
                processor: processor,
                package: Purchase::Package.new(
                    package: package,
                    recipient: recipient,
                )
            )
        end
    end

    def package_obj
        purchase.package
    end

    def package_id
        purchase.package.id if purchase
    end

    def package_activated_at
        purchase.activated_at if purchase
    end

    def package_for_id
        purchase.recipient.id if purchase
    end

    def processor_name
        processor.try(:processor_name)
    end

    def processor_id
        processor.try(:external_id)
    end

    def processor_url
        processor.try(:external_url)
    end

    def processor_can_void?
        processor.try(:can_void?)
    end

    def fake?
        processor.try(:fake?)
    end

    def package_for
        if user_id = package_for_id
            User.find(user_id)
        end
    end

    def amount_in_dollars
        BigDecimal.new(total) / 100
    end

    def formatted_dollars(show_cents: false)
        FormattingHelper.format_dollars(cents: total, show_cents: show_cents)
    end

    def success?
        status == Status::PAYED
    end
    alias_method :payed?, :success?

    def refunded?
        status == Status::REFUNDED
    end

    def error_message
        case status
            when Status::DECLINED
                processor.error_message
            when Status::INVALID
                note
        end
    end

    def status_text
        case status
            when Status::UNPAYED
                "Not Payed"
            when Status::PAYED
                "Approved"
            when Status::REFUNDED
                "Refunded"
            when Status::DECLINED
                "Declined"
            when Status::INVALID
                note
        end
    end

    def status_class
        case status
            when Status::PAYED
                "success"
            when Status::REFUNDED
                "info"
            when Status::DECLINED
                "danger"
            when Status::INVALID
                "warning"
        end
    end

    def process!
        if purchase_valid?
            if user && user.shop_lockout_at
                self.status = Status::DECLINED
            else
                save! # Save before processing, so we have a Transaction object even if something goes wrong

                if processor.process!
                    self.status = Status::PAYED
                    give_package!
                    send_notification_email!
                    Gift.offer!(giver: user, receiver: purchase.recipient, package: purchase.package)
                else
                    self.status = Status::DECLINED
                end
            end
        end

        save!

        if self.status == Status::DECLINED && self.user
            self.user.check_shop_lockout
        end
    end

    def refund!
        payed? or raise Error.new("Only payed transactions can be refunded")
        processor or raise Error.new("No payment processor")

        processor.refund!
        self.status = Status::REFUNDED
        save!
        revoke_package!
    end

    def purchase_valid?
        unless purchase.recipient.accepts_purchases_from?(user)
            self.status = Status::INVALID
            self.note = "Recipient is not the buyer and is not accepting gifts"
            return false
        end

        unless purchase.valid_now?
            self.status = Status::INVALID
            self.note = purchase.errors.full_messages.join("\n")
            return false
        end

        unless purchase.default_price == total
            self.status = Status::INVALID
            self.note = "Package price (#{purchase.default_price}) is not equal to the transaction amount (#{total})"
            return false
        end

        true
    end

    def give_package!(start: nil)
        purchase.activated_at = start || Time.now
        purchase.join_group!
    end

    def revoke_package!
        purchase.recipient.leave_group(purchase.package.group)
    end

    private

    def send_notification_email!
        if user && self.email ||= user.email
            UserMailer.transaction_receipt(self).deliver
            self.email_sent = true
        end
    end
end
