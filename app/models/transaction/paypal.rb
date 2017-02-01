class Transaction
    class Paypal < Processor

        processor_name "PayPal"

        field :token, type: String
        field :payer_id, type: String
        field :transaction_id, as: :external_id, type: String
    end
end
