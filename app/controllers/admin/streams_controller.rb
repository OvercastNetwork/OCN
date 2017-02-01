module Admin
    class StreamsController < BaseController
        def self.general_permission
            ['stream', 'admin', true]
        end

        skip_before_filter :authenticate_admin
        before_filter :find_stream, :only => [:edit, :update, :destroy]

        def index
            @streams = a_page_of(Stream.order_by(public: -1, priority: 1, channel: 1))
        end

        def new
            @stream = Stream.new
        end

        def create
            @stream = Stream.new(params[:stream])
            if @stream.save
                redirect_to admin_streams_path, :notice => "Stream created"
            else
                render :new, :alert => "Stream failed to create"
            end
        end

        def edit
        end

        def update
            if @stream.update_attributes(params[:stream])
                redirect_to_back edit_admin_stream_path(@stream), :notice => "Stream updated"
            else
                render :edit, :alert => "Stream failed to update"
            end
        end

        def destroy
            @stream.destroy
            redirect_to admin_streams_path, :notice => "Stream deleted"
        end

        private

        def find_stream
            @stream = model_param(Stream)
            breadcrumb @stream.channel
        end
    end
end
