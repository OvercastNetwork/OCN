require 'open-uri'
# Simple client for parts of Mojang's HTTP API
module Mojang
    class Error < Exception; end

    class << self
        attr_accessor :logger
        attr_accessor :timeout

        def log(msg)
            logger.debug(msg) if logger
        end

        # Just gets a URL and wraps errors in Mojang::Error
        def api_get(url, &block)
            Timeout.timeout(timeout || 0) do
                open(url, &block)
            end
        rescue OpenURI::HTTPError => ex
            log "Failed to get url #{url}: #{ex}"
            raise Error
        rescue Timeout::Error
            log "Timed out (#{timeout}) getting url #{url}"
            raise Error
        end

        def username_url(name)
            "https://api.mojang.com/users/profiles/minecraft/#{name}"
        end

        def username_to_uuid(name)
            api_get(username_url(name)) do |io|
                JSON.parse(io.read)['id']
            end
        end

        def username_taken?(name)
            case code = open("https://api.mojang.com/users/profiles/minecraft/#{name}").status[0].to_i
                when 200
                    true
                when 204
                    false
                else
                    log "Unexpected response code #{code} from name check: #{url}"
                    raise Error
            end
        end
    end

    # Structure returned by the profile endpoint
    class Profile
        attr_reader :id, :name, :textures

        class << self
            def from_uuid(uuid)
                Mojang.log "Getting profile for UUID #{uuid} using profile endpoint"

                uuid = User.normalize_uuid(uuid)
                Mojang.api_get "https://sessionserver.mojang.com/session/minecraft/profile/#{uuid}" do |io|
                    json = io.read
                    raise Error if json.blank? # Responds with 204 No Content if session not found
                    from_json(json)
                end
            end

            def from_json(json)
                new(JSON.parse(json))
            end
        end

        def initialize(data)
            @id = data['id']
            @name = data['name']

            data['properties'].to_a.each do |property|
                if property['name'] == 'textures' && property['value']
                    @textures = Textures.from_base64(property['value'])
                end
            end
        end

        def skin_url
            @textures && @textures.skin_url
        end

        def skin
            @textures && @textures.skin
        end
    end

    # Sub-structure nested in Profile (the part that is Base64 encoded and signed)
    class Textures
        attr_accessor :profile_id, :profile_name, :timestamp, :skin_url

        class << self
            def from_base64(base64)
                from_json(Base64.decode64(base64))
            end

            def from_json(json)
                new(JSON.parse(json))
            end
        end

        def initialize(data)
            @profile_id = data['profileId']
            @profile_name = data['profileName']
            @timestamp = Time.at(data['timestamp'].to_i / 1000) if data['timestamp']
            @skin_url = data['textures'].to_h['SKIN'].to_h['url']
        end

        def skin
            @skin ||= Skin.from_url(skin_url) if skin_url
        end
    end

    # Skin PNG image
    class Skin
        attr_accessor :png

        class << self
            # Use the legacy skin API
            def from_username(username)
                Mojang.log "Getting skin for username #{username} using legacy endpoint"

                from_url("http://skins.minecraft.net/MinecraftSkins/#{username}.png")
            end

            def from_url(url)
                Mojang.api_get url do |io|
                    new(io.read)
                end
            end

            alias_method :from_png, :new

            def alex?(uuid)
                uuid = uuid.hexdigest if uuid.is_a?(UUIDTools::UUID)

                # In Java, UUID.hashCode() even is Steve, odd is Alex.
                # hashCode() is xor of all four 32bit segments of the UUID.
                uuid.scan(/.{8}/).reduce(false) do |parity, slice|
                    parity ^ slice[7].to_i(16).odd?
                end
            end

            def steve?(uuid)
                !alex?(uuid)
            end
        end

        def initialize(png)
            @png = png
        end

        def image
            @image ||= ChunkyPNG::Image.from_blob(@png)
        rescue ChunkyPNG::Exception => ex
            Mojang.log "#{ex.class.name} decoding skin image: #{ex.message}"
            nil
        end

        def face
            image.crop(8, 8, 8, 8)
        end

        def hat
            image.crop(40, 8, 8, 8)
        end

        def face_with_hat
            face.compose(hat, 0, 0)
        end
    end
end

module ChunkyPNG
    module Chunk
        def self.verify_crc!(type, content, found_crc)
            # No-op this because there is no way to disable it and
            # it fails for many skins that otherwise work fine.
        end
    end
end
