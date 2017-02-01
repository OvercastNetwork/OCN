module Admin
    class ForumsController < BaseController

        before_filter :find_forum, :only => [:edit, :update, :destroy]

        def index
            @forums = Forem::Forum.all.order_by([:order, :asc])
        end

        def new
            @forum = Forem::Forum.new
        end

        def create
            @forum = Forem::Forum.new(params[:forum])
            if @forum.save
                redirect_to admin_forums_path, :notice => "Forum created"
            else
                redirect_to_back new_admin_forum_path, :alert => "Forum failed to create"
            end
        end

        def edit
        end

        def update
            if @forum.update_attributes(params[:forum])
                redirect_to_back edit_admin_forum_path(@forum), :notice => "Forum updated"
            else
                redirect_to_back edit_admin_forum_path(@forum), :alert => "Forum failed to update"
            end
        end

        def destroy
            @forum.destroy
            redirect_to admin_forums_path, :notice => "Forum deleted"
        end

        protected

        def find_forum
            @forum = model_param(Forem::Forum)
            breadcrumb @forum.title
        end
    end
end
