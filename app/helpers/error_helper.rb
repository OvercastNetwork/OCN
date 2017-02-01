module ErrorHelper
    class ErrorResponse < Exception
        attr_reader :status
        def initialize(message, status:)
            super(message)
            @status = status
        end
    end

    class BadRequest < ErrorResponse
        def initialize(message = "Bad request")
            super(message, status: 400)
        end
    end

    class Unauthorized < ErrorResponse
        def initialize(message = "Unauthorized")
            super(message, status: 401)
        end
    end

    class Forbidden < ErrorResponse
        def initialize(message = "Forbidden")
            super(message, status: 403)
        end
    end

    class NotFound < ErrorResponse
        def initialize(message = "Not found")
            super(message, status: 404)
        end
    end
end
