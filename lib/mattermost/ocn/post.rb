module Mattermost
    module OCN
        class Post < ::Mattermost::Post
            include OCN::Formatting

            def initialize(icon: nil, username: nil, user: nil, text: '')
                if user
                    super(icon: avatar_url(user),
                          username: user.username,
                          text: text)
                else
                    super(icon: image_url(icon),
                          username: username,
                          text: text)
                end
            end
        end
    end
end
