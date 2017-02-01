module Forem
    module ForumsHelper
        def topics_count(forum)
            if admin_or_moderator?(forum)
                forum.topics.count
            else
                forum.topics.approved.count
            end
        end

        def posts_count(forum)
            if forum.posts_count == nil
                forum.posts_count = forum.topics.inject(0) {|sum, topic| topic.posts.count + sum }
                forum.save
            end
            forum.posts_count
        end
    end
end
