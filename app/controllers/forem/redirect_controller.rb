class Forem::RedirectController < ApplicationController
    def forum
        return redirect_to forum_path(params[:forum_id])
    end

    def topic
        return redirect_to topic_path(params[:topic_id])
    end

    def posts
        post = model_param(Forem::Post, :post_id)
        return not_found unless post.can_view? && post.topic.try!(:can_view?)

        page = (post.topic.index_of_post(post) / PGM::Application.config.global_per_page) + 1
        return redirect_to "#{topic_url(post.topic, page: page)}##{post.id}"
    end

    def subscriptions
        return redirect_to my_subscriptions_path
    end
end
