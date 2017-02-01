class Server
    module Tournaments
        extend ActiveSupport::Concern

        included do
            # Practice servers will have these fields set to the particular tournament
            # and team they belong to. The team will be automatically whitelisted.
            belongs_to :team
            belongs_to :tournament

            attr_cloneable :team, :tournament

            api_property :team
        end # included do
    end # Tournaments
end
