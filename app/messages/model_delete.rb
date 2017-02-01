class ModelDelete < ModelMessage
    field :document_id

    def initialize(doc, **opts)
        super(
            model: doc.class,
            payload: {
                document_id: doc.id
            },
            **opts
        )
    end
end
