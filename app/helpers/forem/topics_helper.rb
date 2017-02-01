module Forem
    module TopicsHelper
        def link_to_latest_post(post)
            text = "#{time_ago_in_words(post.created_at, false, :vague => true)} ago"
            link_to text, root_path + "posts/" + post.id.to_s, {:rel => 'tooltip', :title => format_time(post.created_at), :data => {:placement => "top", :container => "body"}}
        end

        def TopicsHelper.filter_topics(user, *topics)
            topics.flatten.delete_if{|t| !t.can_index?(user)}
        end
    end
end
