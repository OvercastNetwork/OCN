class ChannelWorker
    include Worker

    # Refresh the most stale channel every 5 seconds.
    # Slow it down in non-production environments, because API requests are limited.

    def self.polling_interval
        if Rails.env.production?
            5.seconds
        else
            5.minutes
        end
    end

    poll delay: polling_interval do
        if user = User.with_oauth2_token_for(:youtube).asc(:channels_refreshed_at).first
            begin
                user.refresh_channels!
            rescue => ex
                error("Exception refreshing channels for user #{user.username}", exception: ex)
            end
        end
    end
end
