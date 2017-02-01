class Server
    module Serialization
        extend ActiveSupport::Concern
        include ApiModel

        # Inline some relations by default:
        #   current_match
        #   current_match.map
        #   next_map
        def api_document(fields: {})
            super(
                fields: {
                    current_match: {
                        fields: {
                            map: true
                        }
                    },
                    next_map: true,
                }.merge(fields)
            )
        end

        # Remove some fields that other servers don't need
        def api_status_document(fields: {})
            api_document(
                fields: {
                    observer_permissions: false,
                    participant_permissions: false,
                    team: false,
                }.merge(fields)
            )
        end
    end # Serialization
end
