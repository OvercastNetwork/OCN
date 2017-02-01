module Channel
    class Youtube < Base
        CHANNEL_ID_REGEX = /\AUC\S{22}\z/
        REFRESH_TIMEOUT = 10.seconds

        field :channel_id, type: String
        field :username, type: String

        validates_format_of :channel_id, with: CHANNEL_ID_REGEX

        index({channel_id: 1}, unique: true, sparse: true)

        before_validation do
            self.service = 'youtube'
        end

        class << self
            def logger
                Rails.logger
            end

            def api_request(**parameters)
                { api_method: GOOGLE::YOUTUBE.channels.list,
                  parameters: { part: 'id,snippet,statistics', **parameters } }
            end

            def refresh_for_user!(user)
                timeout(REFRESH_TIMEOUT) do
                    if token = user.oauth2_token_for(:youtube) and auth = token.fresh_client
                        # Save the user's old channel set
                        old_channels = user.channels.to_a

                        begin
                            result = GOOGLE::CLIENT.execute!(authorization: auth, **api_request(mine: true))
                            if result.success?
                                new_channels = refresh_from_api_result(result)
                                user.channels = new_channels
                                new_channels.each{|ch| ch.users << user } # Mongoid should do this implicitly, but it doesn't
                            else
                                logger.error "Youtube channel refresh failed for unknown reasons"
                            end

                            # Destroy any orphan channels from the old set
                            old_channels.each do |channel|
                                channel.reload
                                if channel.users.empty?
                                    logger.info "Destroying orphan channel #{channel.id}"
                                    channel.destroy
                                end
                            end

                            user.channels
                        rescue Google::APIClient::AuthorizationError
                            Rails.logger.warn "Authorization failure for #{user.username}, assuming revoked OAuth token"
                            user.channels = []
                            token.destroy
                        rescue Google::APIClient::ServerError => ex
                            # These 500 errors are common, presumably there is nothing we can do about them
                            raise ex unless ex.message =~ /^Internal Error|Backend Error$/
                        end
                    end
                end
            end

            def refresh_from_api_result(result)
                result.data.items.map do |item|
                    refresh_from_api_item(item)
                end.compact.select(&:valid?)
            end

            def refresh_from_api_item(item)
                attrs = attributes_from_api_item(item)
                unless attrs[:name].blank? # Deleted channels are sometimes named ""
                    channel = find_or_initialize_by(channel_id: item.id)
                    channel.update_attributes!(attrs.merge(refreshed_at: Time.now.utc))
                    channel
                end
            end

            def attributes_from_api_item(item)
                {
                    channel_id: item.id,
                    name: item.snippet.title,
                    thumbnail_url: item.snippet.thumbnails.default.url,

                    videos: item.statistics.videoCount,
                    views: item.statistics.viewCount,
                    subscribers: item.statistics.hiddenSubscriberCount ? nil : item.statistics.subscriberCount
                }
            end
        end

        def url
            if username
                "https://www.youtube.com/user/#{username}"
            elsif channel_id
                "https://www.youtube.com/channel/#{channel_id}"
            end
        end
    end
end
