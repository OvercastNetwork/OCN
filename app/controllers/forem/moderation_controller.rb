module Forem
    class ModerationController < Forem::ApplicationController

        def posts
            return redirect_to_back :alert => 'Invalid action specified.' unless %w(delete hide approve).include?(params[:event])

            params[:posts] ||= {}
            posts = []

            return redirect_to_back :alert => 'No posts specified.' unless params[:posts].any? {|k, v| v['post'] == '1'}

            params[:posts].each do |post_id, hash|
                if hash['post'] == '1'
                    post = Post.where(:_id => post_id).first
                    unless post.nil?
                        return redirect_to_back :alert => "You do not have permission to #{params[:event]} one or more of your selected posts." unless post.send(:"can_#{params[:event]}?", current_user)
                        return redirect_to_back :alert => 'You may not moderate the original post.' if post.topic.posts.first == post
                        posts << post unless post.nil?
                    end
                end
            end

            return redirect_to_back :alert => 'No posts specified.' if posts.empty?

            Post.moderate!(posts, params[:event])
            redirect_to_back :alert => 'Successfully performed moderation.'
        end

    end
end
