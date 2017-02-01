require 'bson/object_id'
require 'mongoid/extensions'

module BSON
    class ObjectId
        # Mongoid changed the JSON representation of ObjectId to {"$oid": "..."}
        # at some point, which breaks all our shit, so revert it for now until
        # we come up with a better solution.
        def as_json(*args)
            to_s
        end
    end
end
