
FactoryGirl.define do
    factory :transaction do
        sequence(:description) { |n| "Transaction#{n}" }
        status Transaction::Status::PAYED

        transient do
            # fields for the purchase subdocument
            package nil
            recipient nil
            activated_at { Time.now }
            duration nil
        end

        before(:create) do |transaction, evaluator|
            package = evaluator.package || create(:package, name: "Package for #{transaction.description}")
            recipient = evaluator.recipient || transaction.user || create(:user, name: "Recipient for #{transaction.name}")

            transaction.purchase = Purchase::Package.new(
                package: package,
                recipient: recipient,
                duration: evaluator.duration || package.time_limit,
                activated_at: evaluator.activated_at
            )

            transaction.processor = Transaction::Braintree.new(payment_method_nonce: 'im_a_nonce')

            transaction.total = package.price if transaction.total.nil? || transaction.total == 0
        end
    end
end
