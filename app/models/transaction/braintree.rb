class Transaction
    class Braintree < Processor

        processor_name "Braintree"

        field :external_id, type: String
        field :payment_method_nonce, type: String, allow_nil: false
        field :external_status, type: String
        field :environment, type: String, allow_nil: false, default: -> { ::Braintree::Configuration.environment.to_s }

        attr_accessible :payment_method_nonce

        def external_url
            if external_id
                merchant_id = BRAINTREE_CONFIG[environment.to_sym][:merchant_id]
                prefix = if environment == 'sandbox' then 'sandbox.' else '' end
                "https://#{prefix}braintreegateway.com/merchants/#{merchant_id}/transactions/#{external_id}"
            end
        end

        def external_object
            ::Braintree::Transaction.find(external_id) if external_id
        end

        def credit_card_identifier
            external_object.credit_card_details.last_4 if external_id
        end

        def can_void?
            %w{authorized submitted_for_settlement}.include?(external_object.status)
        end

        def fake?
            environment == 'sandbox'
        end

        def process!
            customer_options = if transaction.user
                begin
                    customer_id = transaction.user_id.to_s
                    ::Braintree::Customer.find(customer_id)
                    {customer_id: customer_id}
                rescue ::Braintree::NotFoundError
                    {customer: {id: customer_id}}
                end
            else
                {}
            end

            result = ::Braintree::Transaction.sale(
                order_id: transaction.id.to_s,
                amount: transaction.amount_in_dollars,
                payment_method_nonce: payment_method_nonce,
                options: {
                    submit_for_settlement: true
                },
                **customer_options
            )

            unless self.success = result.success?
                self.error_message = result.message
            end

            if result.transaction
                self.external_id = result.transaction.id
                self.external_status = result.transaction.status
            end

            result.success?
        end

        def refund!
            bt = external_object

            result = if can_void?
                ::Braintree::Transaction.void(bt.id)
            else
                ::Braintree::Transaction.refund(bt.id)
            end

            result.success? or raise Error.new(result.message)
        end
    end
end
