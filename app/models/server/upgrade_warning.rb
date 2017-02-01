class Server
    module UpgradeWarning
        extend ActiveSupport::Concern

        included do
            # Show a warning to players who join the server with a client version older
            # than this, and tell them the server will be upgrading at this date.
            field :upgrade_version, type: String
            field :upgrade_date, type: Time
        end
    end # UpgradeWarning
end
