module Forem
    class PostsController < Forem::ApplicationController
        before_filter :authenticate_forem_user
        before_filter :find_topic
        before_filter :find_post, :only => [:edit, :update, :pin]
        before_filter :check_post_editable, :only => [:edit, :update, :pin]
        before_filter :check_create, :only => [:new, :create]
        before_filter :block_banned_users, :only => [:new, :create, :update, :pin]

        def new
            @post = @topic.posts.build
            if params[:reply_to_id]
                @reply_to = model_param(@topic.posts, :reply_to_id)
                raise NotFound unless @reply_to.can_view? && !@reply_to.first_post?
            end
        end

        def create
            Forem::Post.with_assignment_role(:creator) do
                @post = @topic.posts.new(params[:post])
            end

            if @post.save
                flash[:notice] = 'Post successfully created.'
                redirect_to post_path(@post)
            else
                params[:reply_to_id] = params[:post][:reply_to_id]
                flash.now[:error] = if @post.errors.messages.empty?
                                        "Post could not be created. If this problem persists, please contact #{ORG::EMAIL}"
                                    else
                                        @post.errors.full_messages.first
                                    end
                render :action => 'new'
            end
        end

        def edit
            if !@post.converted?
                @post.convert
                @converted = true
            end
        end

        def update
            Forem::Post.with_assignment_role(:editor) do
                if @post.update_attributes(params[:post])
                    redirect_to '/forums/posts/' + @post.id.to_s, :notice => 'Post successfully updated.'
                else
                    flash.now.alert = "Post could not be edited. If this problem persists, please contact #{ORG::EMAIL}"
                    render :action => 'edit'
                end
            end
        end

        def pin
            return redirect_to_back topic_path(@topic), :alert => 'You do not have permission to pin this post.' unless @post.can_pin?(current_user)
            return redirect_to_back topic_path(@topic), :alert => 'You may not pin the original post.' if @post.first_post?

            @post.pinned = !@post.pinned?
            @post.save
            redirect_to '/forums/posts/' + @post.id.to_s, notice: "Post #{@post.pinned? ? 'pinned' : 'unpinned'}."
        end

        private

        def check_create
            redirect_to_back topic_path(@topic), :alert => 'You do not have permission to reply to this topic.' unless @topic.can_reply?(current_user)
        end

        def check_post_editable
            redirect_to_back topic_path(@topic), :alert => 'You do not have permission to edit this post.' unless @post.can_edit?(current_user)
        end

        def find_post
            not_found unless @post = model_param(@topic.posts) and @post.can_view?
        end

        def find_topic
            not_found unless @topic = model_param(Forem::Topic, :topic_id) and @topic.can_view?
        end

        def last_page
            (@topic.posts.count.to_f / Forem.per_page.to_f).ceil
        end
    end
end
