CROWDIN = -> {
    if Rails.env.production?
        Crowdin::CacheClient.new(
            project_id: '...',
            api_key: '...'
        )
    else
        Crowdin::CacheClient.new(
            project_id: '...',
            api_key: '...'
        )
    end
}

Translation.define do
    translation 'broadcasts' do
        repo :config
        path 'localized/broadcasts'
        files '**/*.xml'
    end
end
