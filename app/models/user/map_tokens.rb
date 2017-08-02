class User
    module MapTokens
        extend ActiveSupport::Concern

        included do
            field :maptokens, type: Integer, default: 0
            api_property :maptokens
            index({maptokens: 1})
        end

        def credit_maptokens(amount)
            return nil if anonymous?
            if amount > 0
                inc(maptokens: amount)
                self
            elsif amount < 0
                where_self
                    .gte(maptokens: -amount)
                    .find_one_and_update({$inc => {maptokens: amount}},
                                         return_document: :after)
            else
                self
            end
        end

        def debit_maptokens(amount)
            credit_maptokens(-amount)
        end

    end
end
