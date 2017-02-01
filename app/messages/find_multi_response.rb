class FindMultiResponse < ModelMessage
    def initialize(model: nil, request: nil, documents: nil, api_documents: nil, **opts)
        model ||= request.model

        opts = {
            model: model,
            in_reply_to: request,
            payload: {
                documents: model.serialized_search_results(request: request, documents: documents, api_documents: api_documents)
            },
        }.merge(opts)

        super(**opts)
    end
end
