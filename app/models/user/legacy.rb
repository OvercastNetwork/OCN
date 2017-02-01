class User
    module Legacy

        # Macros for use on other models that refer to User
        module Macros
            extend ActiveSupport::Concern

            module ClassMethods
                # Define a legacy User reference by player_id
                #
                # On the foreign model, this defines both a belongs_to relation and a
                # String field for the foreign key.
                #
                # On the User model, this defines a reciprocal has_many relation to the
                # foreign model. Assuming this definition appears in the foreign model,
                # the inverse relation will not exist until that model has loaded. To
                # ensure that happens immediately after User loads, add a reference to
                # the foreign model at the end of user.rb. This is kind of ugly, but it's
                # worth it to avoid repeating three different field names per relation.
                #
                # @param relation       Name of the accessor that returns a User object
                # @param external       Name of the accessor that returns a player_id string
                # @param internal       Name of the field in the database containing the player_id string
                # @param inverse_of     Name of the inverse relation on the User model (required)
                def belongs_to_legacy_user(relation:, external:, internal:, inverse_of:)
                    # This needs to be first
                    field internal, as: external

                    belongs_to relation,
                               class_name: User.name,
                               primary_key: :player_id,
                               foreign_key: internal,
                               inverse_of: inverse_of

                    # The belongs_to macro removes the :as option somehow, so we have to restore it
                    fields[internal.to_s].options[:as] = external

                    # Convert output of User#api_player_id to a plain player_id
                    # This allows API documents to be written back without modification
                    before_validation do
                        pid = read_attribute(internal)
                        if pid.is_a? Array
                            write_attribute(internal, pid[0])
                        end
                    end

                    # Define inverse relation on User
                    User.has_many inverse_of,
                                  class_name: name,
                                  primary_key: :player_id,
                                  foreign_key: internal,
                                  inverse_of: relation
                end
            end
        end
    end
end
