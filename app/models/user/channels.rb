class User
    module Channels
        extend ActiveSupport::Concern

        included do
            field :channels_refreshed_at, type: Time

            has_and_belongs_to_many :channels, class_name: 'Channel::Base'
            index({channel_ids: 1})
            index({channels_refreshed_at: 1})
        end

        def channels_for(service)
            channels.where(service: service.to_s)
        end

        def refresh_channels!
            Channel::Youtube.refresh_for_user!(self)
        ensure
            # Update the timestamp even if the refresh fails, so we don't
            # get stuck refreshing the same broken user repeatedly
            self.channels_refreshed_at = Time.now

            # Call non-raising save, because we don't want to raise inside an ensure block
            save
        end

        def youtube_url
            if youtube
                if youtube.size == 24
                    "https://www.youtube.com/channel/#{youtube}"
                else
                    "https://www.youtube.com/user/#{youtube}"
                end
            end
        end
    end
end
