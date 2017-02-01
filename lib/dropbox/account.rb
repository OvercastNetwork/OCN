module Dropbox
    class Account < Model
        field :account_id, :name, :email, :country, :locale,
              :referral_link, :is_paired, :account_type, :is_teammate

        def <=>(account)
            account_id <=> account.account_id
        end
    end
end
