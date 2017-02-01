module Forem
    module PostsHelper
        def post_path(post)
            "#{Engine.url_helpers.root_path}posts/#{post.id}"
        end
    end
end
