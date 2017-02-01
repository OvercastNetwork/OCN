class User
    # Skin fetching/caching module for User model
    module Skin
        extend ActiveSupport::Concern

        Mojang.logger = Rails.logger
        Mojang.timeout = 5.seconds

        SKIN_CACHE_EXPIRY = 7.days

        DEFAULT_SKINS = [:steve, :alex].mash do |name|
            png = File.read(File.join(File.dirname(__FILE__), "skin_#{name}.png"),
                            encoding: Encoding::BINARY)
            [name, Mojang::Skin.from_png(png)]
        end

        included do
            # Most recent skin URL extracted during Minecraft authentication
            # or from Mojang's HTTP endpoint. This will be nil if the User
            # is using the default skin.
            field :skin_url, :type => String

            # Raw PNG binary
            field :skin_png, :type => BSON::Binary

            # Last time skin_url was verified to be the user's actual skin
            field :skin_verified_at, :type => Time

            # Last time we tried to get a skin_url from Mojang's API.
            # No attempt should be made within one minute of this.
            field :skin_verify_attempted_at, :type => Time

            before_validation do
                # Invalidate the cache when the skin URL changes
                if skin_url_changed?
                    self.skin_png = nil
                    @skin = nil
                    skin(save: false)
                end
            end
        end

        def skin_blob=(blob)
            textures = Mojang::Textures.from_base64(blob)
            self.skin_url = textures.skin_url if textures.skin_url
        end

        def skin_url=(url)
            self.skin_verified_at = Time.now
            super
        end

        # Check if the User's skin_url is verified to be their actual skin
        def skin_verified?
            skin_verified_at && skin_verified_at + SKIN_CACHE_EXPIRY > Time.now
        end

        def skin_verify_allowed?
            skin_verify_attempted_at.nil? || skin_verify_attempted_at + 1.minute <= Time.now
        end

        # Refresh skin_url through Mojang's API if it is stale or absent.
        # If skin_url is refreshed, skin_png will be cleared.
        def verify_skin
            if skin_verified?
                true
            elsif skin_verify_allowed?
                # If we don't have a fresh skin URL, try to get one from Mojang
                self.skin_verify_attempted_at = Time.now
                profile = Mojang::Profile.from_uuid(uuid)
                self.skin_url = profile.skin_url # Will be nil for default skin
                true
            end
        rescue Mojang::Error
            false
        end

        # Get the user's skin as a Mojang::Skin object. This will use any cached
        # data available, and otherwise do anything necessary to fetch the skin.
        # The cache will be populated with anything that is fetched, but the cache
        # will not be persisted until the User is saved, which this method does not do.
        def skin(save: true)
            unless @skin
                # If skin_url is stale, this will refresh it and clear skin_png
                verified = verify_skin

                if skin_png
                    # If we still have a cached PNG after verification, then either
                    # the skin_url was already fresh, or verification failed. Either
                    # way, we will use the cached PNG.
                    @skin = Mojang::Skin.from_png(skin_png.data)
                elsif verified
                    # The skin_url is verified, but no PNG is cached, which means:
                    if skin_url
                        # the url was refreshed,
                        begin
                            @skin = Mojang::Skin.from_url(skin_url)
                            self.skin_png = BSON::Binary.new(@skin.png, :generic)
                        rescue Mojang::Error
                            # Probably a timeout
                            @skin = default_skin
                        end
                    else
                        # or the user has no skin
                        @skin = default_skin
                    end
                else
                    # We could not get a fresh skin_url, and we have nothing cached,
                    # so try to get a PNG from the legacy API.
                    begin
                        @skin = Mojang::Skin.from_username(username)
                        self.skin_png = BSON::Binary.new(@skin.png, :generic)
                    rescue Mojang::Error
                        # If the legacy API fails too, give up and use the default skin,
                        # which is probably the right one.
                        @skin = default_skin
                    end
                end

                save! if save
            end

            @skin
        end

        # Clear all cached skin data and save the user with #save!
        def clear_skin_cache!
            @skin = nil
            self.skin_url = nil
            self.skin_png = nil
            self.skin_verified_at = nil
            save!
        end

        def default_skin_name
            if uuid && Mojang::Skin.alex?(uuid)
                :alex
            else
                :steve
            end
        end

        def default_skin
            DEFAULT_SKINS[default_skin_name]
        end

        # Render the player's avatar (face and hat) at the given size,
        # returning a ChunkyPNG::Image object.
        def avatar(size)
            size = 600 if size > 600
            @avatars ||= {}
            @skin = default_skin unless skin.image
            @avatars[size] ||= skin.face_with_hat.resample_nearest_neighbor(size, size)
        end
    end
end
