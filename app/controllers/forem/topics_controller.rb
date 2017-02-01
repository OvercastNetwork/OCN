module Forem
    class TopicsController < Forem::ApplicationController
        before_filter :authenticate_forem_user, except: [:show]
        before_filter :find_topic_and_forum, only: [:show, :unread,
                                                    :edit, :update,
                                                    :toggle_hide, :toggle_lock, :toggle_pin,
                                                    :subscribe, :unsubscribe]
        before_filter :find_forum, only: [:new, :create]
        before_filter :block_banned_users, only: [:new, :create]

        def show
            return not_found unless @topic.can_view?

            @posts = @topic.indexed_posts

            # Get a page of posts in chrono order and convert to an array.
            # Preserve the object with the page info in @posts_page
            page = page_param(@posts)
            @posts_page = a_page_of(@posts, page: page)
            @posts = @posts_page.to_a

            if page == 1
                # On page 1, insert the pinned posts after the first post,
                # and delete them if they appear elsewhere on the page.
                pinned = @topic.pinned_posts.to_a
                first, *rest = @posts - pinned
                @posts = [first, *pinned, *rest]
            end

            # Filter out hidden posts (after pagination, so pages are consistent)
            @posts.select!(&:can_view?)

            # Build the action button/list next to each post
            @post_actions = @posts.mash do |post|
                post.set_relation(:topic, @topic) # Avoid a query for every post

                first = page == 1 && post == @posts.first
                actions = []
                actions << ["Quote", :get, new_topic_post_path(@topic, reply_to_id: post)] if @topic.can_reply? && !first
                actions << ["Edit", :get, edit_topic_post_path(@topic, post)] if post.can_edit?
                actions << [post.pinned? ? "Unpin" : "Pin", :post, pin_topic_post_path(@topic, post)] if post.can_pin? && !first
                actions << ["Punish", :get, main_app.url_for(:controller => '/punishments', :action => 'new', :name => post.user.to_s, :from_post => post.id)] if Punishment.can_issue_forum?(current_user) and current_user != post.user

                [post, actions]
            end

            @can_moderate_topic = @topic.can_moderate?
            @can_moderate_posts = @posts.any?(&:can_moderate?)

            @topic.register_view_by!
        end

        def new
            return redirect_to_back forum_path(@forum), :alert => 'You do not have permission to create topics in this forum.' unless Forem::Topic.can_create?(@forum, current_user)

            @topic = @forum.topics.build
            post = @topic.posts.build
            @topic.user = post.user = forem_user

            # Show cooldown message in advance
            @topic.enforce_cooldown
            if msg = @topic.errors.full_messages.first
                flash.now[:alert] = msg
            end
        end

        def create
            return redirect_to_back forum_path(@forum), :alert => 'You do not have permission to create topics in this forum.' unless Forem::Topic.can_create?(@forum, current_user)

            @topic = Forem::Topic.create_from_params(params, @forum, forem_user)

            if @topic.errors.empty?
                flash[:notice] = 'Topic successfully created.'
                redirect_to @topic
            else
                flash.now[:error] = @topic.errors.full_messages.first
                render action: 'new'
            end
        end

        def edit
            redirect_to_back forem.topic_path(@topic), :alert => 'You do not have permission to edit this topic.' unless @topic.can_edit_title?(current_user) || @topic.can_move?(current_user)
        end

        def update
            unless params[:topic][:subject].to_s == @topic.subject.to_s
                return redirect_to_back topic_path(@topic), :alert => "You do not have permission to edit this topic's title." unless @topic.can_edit_title?(current_user)
            end

            unless params[:topic][:forum_id].to_s == @topic.forum.id.to_s
                return redirect_to_back topic_path(@topic), :alert => 'You do not have permission to move this topic.' unless @topic.can_move?(current_user)
                forum = Forem::Forum.where(:id => params[:topic][:forum_id]).first
                return redirect_to_back topic_path(@topic), :alert => 'An error occurred in attempting to locate the requested forum.' unless !forum.nil? && forum.can_view?(current_user)
                return redirect_to_back topic_path(@topic), :alert => 'You do not have permission to move this topic to the selected forum.' unless Forem::Topic.can_create?(forum, current_user)
            end

            Forem::Topic.with_assignment_role(:editor) do
                if @topic.update_attributes(params[:topic])
                    flash[:notice] = 'Topic successfully updated.'
                    redirect_to forem.topic_path(@topic)
                else
                    flash.alert = "Topic failed to update. If the problem persists, please contact #{ORG::EMAIL}"
                    render :action => 'edit'
                end
            end
        end

        def toggle_hide
            return redirect_to_back forem.topic_path(@topic), :alert => "You do not have permission to #{@topic.hidden? ? 'un-hide' : 'hide'} this topic." unless @topic.hidden? ? @topic.can_approve?(current_user) : @topic.can_hide?(current_user)

            @topic.toggle!(:hidden)
            @topic.unsubscribe_all if @topic.hidden
            flash[:notice] = 'Topic is now ' + (@topic.hidden? ? 'hidden' : 'visible') + '.'
            redirect_to forem.topic_path(@topic)
        end

        def toggle_lock
            return redirect_to_back forem.topic_path(@topic), :alert => "You do not have permission to #{@topic.locked? ? 'unlock' : 'lock'} this topic." unless @topic.locked? ? @topic.can_unlock?(current_user) : @topic.can_lock?(current_user)

            @topic.toggle!(:locked)
            flash[:notice] = 'Topic is now ' + (@topic.locked? ? 'locked' : 'unlocked') + '.'
            redirect_to forem.topic_path(@topic)
        end

        def toggle_pin
            return redirect_to_back forem.topic_path(@topic), :alert => "You do not have permission to #{@topic.pinned? ? 'unpin' : 'pin'} this topic." unless @topic.pinned? ? @topic.can_unpin?(current_user) : @topic.can_pin?(current_user)

            @topic.toggle!(:pinned)
            flash[:notice] = 'Topic is now ' + (@topic.pinned? ? 'pinned' : 'unpinned') + '.'
            redirect_to forem.topic_path(@topic)
        end

        def subscribe
            return redirect_to_back root_path, :alert => 'You do not have permission to view this topic.' unless @topic.can_view?(current_user)

            @topic.subscribe_user(current_user_safe)
            redirect_to topic_url(@topic), :notice => 'Successfully subscribed to topic.'
        end

        def unsubscribe
            @topic.unsubscribe_user(current_user_safe)
            redirect_to topic_url(@topic), :notice => 'Successfully un-subscribed from topic.'
        end

        def my_subscriptions
            @subscriptions = a_page_of(current_user_safe.subscriptions.subscribable_type(Forem::Topic).active.desc(:updated_at))
        end

        def clear_subscriptions
            unless forem_user.nil?
                current_user_safe.subscriptions.subscribable_type(Topic).cancel!
                redirect_to root_path, :alert => 'Cleared all subscriptions.'
            end
        end

        def my_posts
            user = my_filter_user('view_posts') or return redirect_to_back my_posts_path, :alert => "Could not locate user."
            @posts = a_page_of(Forem::Post.latest_by(user))
            @title = user == current_user ? 'My Posts' : "#{user}'s Posts"
        end

        def my_topics
            user = my_filter_user('view_topics') or return redirect_to_back my_topics_path, :alert => "Could not locate user."
            @topics = a_page_of(Forem::Topic.user(user).by_visibly_updated)
            @title = user == current_user ? 'My Topics' : "#{user}'s Topics"
        end

        def unread
            return redirect_to_back root_path, :alert => 'You do not have permission to view this topic.' unless @topic.can_view?(current_user)
            if (last_seen = @topic.last_seen_by(current_user)) &&
                (post = Forem::Post.for_topic(@topic).gte(created_at: last_seen).first) &&
                post.can_view?(current_user)

                redirect_to post_path(post)
            else
                redirect_to @topic
            end
        end

        protected

        def find_forum
            not_found unless @forum = model_param(Forem::Forum, :forum_id)
        end

        def find_topic_and_forum
            return not_found unless (@topic = Forem::Topic.find(params[:id])) && @forum = @topic.forum
        end

        def my_filter_user(perm_node)
            if params[:user] && current_user_safe.has_permission?('misc', 'player', perm_node, true)
                User.by_username(params[:user])
            else
                current_user_safe
            end
        end
    end
end
