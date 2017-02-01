module Api
    class ApiController < CommonController
        include JsonController
        include ParamsHelper

        PROTO_HEADER = 'X-OCN-Version'

        around_filter :set_current_user
        around_filter :set_protocol_version
        after_filter :clear_cache
        respond_to :json

        def clear_cache
            Cache::RequestManager.clear_request_cache
        end

        def index
            respond({:status => true})
        end

        protected

        def set_current_user
            User.with_current(User.console_user) { yield }
        end

        # Protocol version spoken by the client (will be ApiModel::PROTOCOL_VERSION if missing)
        attr_reader :request_proto
        def set_protocol_version
            if @request_proto = request.headers[PROTO_HEADER]
                @request_proto = @request_proto.to_i
                ApiModel.with_protocol_version(@request_proto) { yield }
            else
                @request_proto = ApiModel.protocol_version
                yield
            end
        end

        rescue_from Mongoid::Errors::DocumentNotFound do |ex|
            render_error(404, "#{ex.klass.name} not found matching #{ex.params.inspect}")
        end
    end
end
