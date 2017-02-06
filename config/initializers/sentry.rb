require 'raven'

Raven.configure do |config|
    config.silence_ready = true
    config.current_environment = Rails.env # Sometimes Raven doesn't pickup the correct environment
    config.timeout = config.open_timeout = 30.seconds # Default timeout is only 1 second

    config.async = Raven.method(:send_event_async)

    # Un-comment these to actually use Raven
    case Rails.env
        # when 'development'
        #     config.dsn = '...'
        # when 'production', 'staging'
        #     config.dsn = '...'
        when ''
        else
            config.environments = []
    end
end

MAP_SENTRY = Raven::Client.new(Raven::Configuration.new)
MAP_SENTRY.configuration.dsn = '...'
MAP_SENTRY.configuration.environments = Raven.configuration.environments
