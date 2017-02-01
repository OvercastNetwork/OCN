class User
    module PvpEncounters
        extend ActiveSupport::Concern

        included do
            api_synthetic :enemy_kills do
                kills.count # TODO: exclude team kills when we have indexes to support the query
            end
        end
    end
end
