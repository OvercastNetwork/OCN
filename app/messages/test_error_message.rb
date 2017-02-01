class TestErrorMessage < BaseMessage
    field :message

    def initialize(message = nil)
        super(payload: {message: message})
    end
end
