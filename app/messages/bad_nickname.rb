class BadNickname < Reply
    field :problem

    def initialize(problem: nil, **opts)
        super(payload: {problem: problem}, success: false, **opts)
    end
end
