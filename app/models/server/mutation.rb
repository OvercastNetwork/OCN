class Server

    module Mutation
        extend ActiveSupport::Concern

        included do
            field :queued_mutations, type: Array, default: [].freeze
            attr_accessible :queued_mutations
            api_property :queued_mutations
        end # included do
    end # Mutation
    
end
