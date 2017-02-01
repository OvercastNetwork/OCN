class User
    # At one point, we attempted to convert all User.player_id references in the
    # entire database to User._id references. We migrated one user at a time,
    # and this flag was set on migrated users. We gave up after about 250k users
    # because it was taking too long, and Mongo's replication was falling way behind.
    module Big3Migration
        extend ActiveSupport::Concern

        included do
            # True if all foreign keys to this user in Session, Death,
            # and Participation have been updated with the user's _id
            field :big3_migrated, type: Boolean, default: false
            index({big3_migrated: 1})
        end # included do
    end # Big3Migration
end
