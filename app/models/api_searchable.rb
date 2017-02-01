module ApiSearchable
    extend ActiveSupport::Concern

    module ClassMethods
        def search(criteria = {})
            search_results(request: search_request(criteria: criteria))
        end

        def search_request_class
            FindRequest
        end

        def search_request(criteria: {}, **opts)
            search_request_class.new(criteria: criteria, model: self, **opts)
        end

        # Return the results of a search on this model, as a query object,
        # using +request+ as search criteria if given.
        #
        # An optional initial query can be given as +documents+, otherwise
        # all documents should be searched.
        #
        # This method performs any filtering and sorting required by searches.
        def search_results(request: nil, documents: nil)
            documents ||= all
            if request
                documents = documents.skip(request.skip) if request.skip
                documents = documents.limit(request.limit) if request.limit
            end
            documents
        end

        # Return the results of a search on this model, as an array of
        # serialized API documents.
        #
        # If +api_documents+ is given, it should be returned unaltered
        # (simplifies logic in some places). Otherwise, if +documents+
        # is given, it should be enumerated and serialized. Otherwise,
        # +search_results+ should be called to get the result set,
        # forwarding the value of +request+.
        #
        # This method controls how search result documents are serialized
        # (i.e. they may have only a subset of fields), and is responsible
        # for any prefetching necessary to generate the serialized documents
        # efficiently.
        def serialized_search_results(request: nil, documents: nil, api_documents: nil)
            api_documents || (documents || search_results(request: request)).map(&:api_document)
        end

        # Return an API message containing the results of forwarding the given
        # arguments to +serialized_search_results+.
        #
        # This is typically a FindMultiResponse message.
        def search_response(request: nil, documents: nil, api_documents: nil)
            FindMultiResponse.new(request: request,
                                  model: self,
                                  documents: documents,
                                  api_documents: api_documents)
        end
    end
end
