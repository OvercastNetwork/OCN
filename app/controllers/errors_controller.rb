class ErrorsController < ApplicationController
    def show
        status = int_param(:status)
        message = case status
            when 400 then "Bad request"
            when 401 then "Unauthorized"
            when 403 then "Forbidden"
            when 404 then "Not found"
            else "Internal error"
        end
        render_error(status, message)
    end
end
