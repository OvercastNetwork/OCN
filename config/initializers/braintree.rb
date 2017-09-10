BRAINTREE_CONFIG = {
    sandbox: {
        environment: :sandbox,
        merchant_id: ENV['BRAINTREE_SANDBOX_MERCHANT_ID'],
        public_key: ENV['BRAINTREE_SANDBOX_PUBLIC_KEY'],
        private_key: ENV['BRAINTREE_SANDBOX_PRIVATE_KEY']
    },
    production: {
        environment: :production,
        merchant_id: ENV['BRAINTREE_PRODUCTION_MERCHANT_ID'],
        public_key: ENV['BRAINTREE_PRODUCTION_PUBLIC_KEY'],
        private_key: ENV['BRAINTREE_PRODUCTION_PRIVATE_KEY']
    }
}

config = if ENV['BRAINTREE_PRODUCTION'] != nil
    BRAINTREE_CONFIG[:production]
else
    BRAINTREE_CONFIG[:sandbox]
end

config.each do |k, v|
    Braintree::Configuration.send("#{k}=", v)
end
