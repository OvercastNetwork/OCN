module Forem
    class ForumsController < Forem::ApplicationController

        before_filter :find_forum, :only => [:show, :mark_read]
        helper 'forem/topics'

        def index
            @whatsnew = a_page_of(Forem::Topic.whats_new)
        end

        def show
            return not_found unless @forum.can_view?(current_user)

            @topics = a_page_of(Forem::Topic.for_forum(@forum)).prefetch(:user, :last_post)

            respond_to do |format|
                format.html
                format.atom { render :layout => false }
            end
        end

        def mark_read
            @forum.mark_topics_read_by
            redirect_to @forum
        end

        protected

        def find_forum
            not_found unless @forum = model_param(Forem::Forum)
        end
    end
end
