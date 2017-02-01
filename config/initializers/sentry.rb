require 'raven'

Raven.configure do |config|
    config.silence_ready = true
    config.current_environment = Rails.env # Sometimes Raven doesn't pickup the correct environment
    config.timeout = config.open_timeout = 30.seconds # Default timeout is only 1 second

    config.async = Raven.method(:send_event_async)

    case Rails.env
        when 'development'
            config.dsn = '...'
        when 'production', 'staging'
            config.dsn = '...'
        else
            config.environments = []
    end
end

MAP_SENTRY = Raven::Client.new(Raven::Configuration.new)
MAP_SENTRY.configuration.dsn = '...'
MAP_SENTRY.configuration.environments = Raven.configuration.environments
