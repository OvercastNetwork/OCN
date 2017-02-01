Rails.configuration.tap do |config|
    config.resource_pack_url_prefix = if Rails.env.production?
        "http://respack:3001"
    else
        "http://respack:3001"
    end
end
