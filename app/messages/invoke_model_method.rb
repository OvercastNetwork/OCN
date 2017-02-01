class InvokeModelMethod < BaseTask
    field :model_name
    field :document_id
    field :method_name
    field :arguments

    def initialize(method:, arguments: [], **opts)
        document = method.receiver
        super(
            payload: {
                model_name: document.class.name,
                document_id: document.id,
                method_name: method.name,
                arguments: arguments.as_json,
            },
            **opts
        )
    end

    def model
        model_name.constantize
    end

    def document
        model.need(document_id)
    end

    def method
        document.method(method_name)
    end

    def call
        method.call(*arguments)
    end
end
