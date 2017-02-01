module Mattermost
    class Post
        include Formatting

        attr :icon, :username, :text

        def initialize(icon: nil, icon_url: nil, username: nil, text: '')
            @icon = if icon_url
                icon_url
            elsif icon
                image_url(icon)
            end
            @username = username
            @text = text
        end

        def as_json
            json = { text: text }
            icon and json[:icon_url] = icon
            username and json[:username] = username
            json
        end

        def to_json
            as_json.to_json
        end
    end
end
