# Mixin for a controller that speaks JSON
module JsonController
    extend ActiveSupport::Concern
    include ActionController::MimeResponds

    included do
        respond_to :json
    end

    protected

    def respond_json(obj: {}, status: 200)
        respond_to do |format|
            format.json do
                render :json => obj, :status => status
            end

            format.html do
                # Round-trip through the JSON parser because Mongoid's document type doesn't know how to pretty print
                render :content_type => 'text/plain', :text => JSON.pretty_generate(JSON.parse(obj.to_json)), :status => status
            end
        end
    end

    def respond_with_message(msg, status: 200)
        respond_json(obj: msg.payload.as_json, status: status)
    end

    def respond(obj = {})
        if obj.is_a?(BaseMessage)
            respond_with_message(obj, status: 200)
        else
            respond_json(obj: obj, status: 200)
        end
    end

    def render_error(status, message)
        respond_with_message(Reply.new(success: false, error: message), status: status)
    end
end
