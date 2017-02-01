class Transaction
    class Google < Processor

        processor_name "Google"

        field :token, type: String
        field :order_number, as: :external_id, type: String
    end
end
