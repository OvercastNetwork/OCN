class ModelUpdate < ModelMessage
    def initialize(doc, **opts)
        super model: doc.class,
              payload: {
                  document: doc.api_document
              },
              **opts
    end

    def document
        @document ||= model.find(payload[:document]['_id'])
    end
end
