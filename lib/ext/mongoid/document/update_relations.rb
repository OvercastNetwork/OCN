module Mongoid
    module Document
        module UpdateRelations
            def can_update_relation?(name)
                name = name.to_s
                if self.class.nested_attributes.key?("#{name}_attributes") && (rel = relations[name])
                    !(rel.many? || rel.embedded? || rel.polymorphic?)
                end
            end

            # Update a referenced document through a relational field on this
            # document, and also update the relation field itself, if necessary.
            # The related document is saved, but this document is not.
            def update_relation!(name, attrs)
                rel = relations[name.to_s] or raise TypeError, "No relation named #{name} on #{self.class}"
                rel.many? and raise TypeError, "Cannot apply nested update to many relation #{name}"
                rel.embedded? and raise TypeError, "Cannot apply nested update to embedded relation #{name}"
                rel.polymorphic? and raise TypeError, "Cannot apply nested update to polymorphic relation #{name}"

                attrs = attrs.stringify_keys

                # Check if the relation key is given in the updated attributes
                key_given = attrs.key?(rel.primary_key)
                key = attrs[rel.primary_key]

                # Get the existing related object
                if obj = send(name)
                    # If a key was specified and does not match the current object, reject it
                    obj = nil if key_given && key != obj[rel.primary_key]
                end

                # If there is no related object at this point, acquire one somehow
                obj ||= if key_given
                    # If a key was specified, try to find an existing object with that key, otherwise create it
                    rel.klass.find_or_initialize_by(rel.primary_key => key)
                else
                    # If no key was specified, create a new object
                    rel.klass.new
                end

                # Update the related object
                obj.update_relations!(attrs)

                begin
                    obj.update_attributes!(attrs)
                rescue Mongo::Error::OperationFailure => ex
                    # This probably means the document was created between now and back
                    # when we called find_or_initialize_by, which can happen if two updates
                    # for the same document arrive close together, and the document doesn't
                    # exist yet, and it has an explicit key.
                    #
                    # We try to fetch the document and update it again, and re-raise the
                    # exception if that doesn't work.
                    if key_given && ex.message =~ /11000/ && (obj = rel.klass.where(rel.primary_key => key).first)
                        obj.update_attributes!(attrs)
                    else
                        raise
                    end
                end

                # Assign the related object to the relation field, which may or may not have changed
                send("#{name}=", obj)
            end

            # Update any nested relations included in the given attributes,
            # and remove them from the given hash.
            def update_relations!(attrs)
                sanitize_for_mass_assignment(attrs).each do |name, value|
                    if can_update_relation?(name)
                        attrs.delete(name)
                        update_relation!(name, value)
                    end
                end
            end
        end

        include UpdateRelations
    end
end
