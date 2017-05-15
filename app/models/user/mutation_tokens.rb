class User
    module MutationTokens
        extend ActiveSupport::Concern

        included do
            field :mutationtokens, type: Integer, default: 0
            api_property :mutationtokens
            index({mutationtokens: 1})
        end

        def credit_mutationtokens(amount)
            return nil if anonymous?
            if amount > 0
                inc(mutationtokens: amount)
                self
            elsif amount < 0
                where_self
                    .gte(mutationtokens: -amount)
                    .find_one_and_update({$inc => {mutationtokens: amount}},
                                         return_document: :after)
            else
                self
            end
        end

        def debit_mutationtokens(amount)
            credit_mutationtokens(-amount)
        end

    end
end
