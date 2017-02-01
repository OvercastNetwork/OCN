class Transaction
    # Payment-processor specific info embedded in Transactions
    class Processor
        include Mongoid::Document
        embedded_in :transaction

        field :success, type: Boolean
        field :error_message, type: String

        class << self
            def processor_name(n = nil)
                @processor_name = n if n
                @processor_name
            end
        end

        delegate :processor_name, to: :class

        def external_url
            # Override me
        end

        def fake?
            false
        end
    end
end

require_dependencies 'transaction/*'
