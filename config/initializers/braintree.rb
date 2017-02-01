BRAINTREE_CONFIG = {
    sandbox: {
        environment: :sandbox,
        merchant_id: "...",
        public_key: "...",
        private_key: "..."
    },
    production: {
        environment: :production,
        merchant_id: "...",
        public_key: "...",
        private_key: "..."
    }
}

config = if Rails.env.production? && !STAGING
    BRAINTREE_CONFIG[:production]
else
    BRAINTREE_CONFIG[:sandbox]
end

config.each do |k, v|
    Braintree::Configuration.send("#{k}=", v)
end
