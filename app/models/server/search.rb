class Server
    module Search
        extend ActiveSupport::Concern
        include ApiSearchable
        
        module ClassMethods
            def search_request_class
                ServerSearchRequest
            end

            def search_results(request: nil, documents: nil)
                documents = super

                if request
                    documents = documents.visible_to_public unless request.unlisted
                    documents = documents.online unless request.offline

                    documents = documents.datacenter(request.datacenter) if request.datacenter.present?
                    documents = documents.network(request.network) if request.network.present?
                    documents = documents.families([*Family.imap_find(*request.families)]) if request.families.present?
                end

                documents.desc(:num_online)
            end

            def serialized_search_results(request: nil, documents: nil, api_documents: nil)
                api_documents || search_results(request: request, documents: documents)
                    .prefetch('current_match.map', 'next_map')
                    .map(&:api_status_document)
            end
        end # ClassMethods
    end # Search
 end
