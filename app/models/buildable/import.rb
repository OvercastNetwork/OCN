module Buildable
    class Import < Transfer
        attr :errors

        def initialize(**opts)
            super
            @errors = []
        end

        def catch_errors(id)
            yield
        rescue BuildError => ex
            add_error(id, ex.message)
            nil
        rescue Psych::Exception => ex
            add_error(id, "Parse error: #{ex.message}")
            nil
        rescue => ex
            add_error(id, "Internal error: #{ex.message}")
            nil
        end

        def add(doc)
            by_id[doc.id] = doc
        end

        def add_error(id = nil, message)
            if id
                errors << "'#{id}': #{message}"
            else
                errors << message
            end
        end

        def add_attrs(id, attrs)
            catch_errors(id) do
                attrs = attrs.stringify_keys

                # Can't import the same document multiple times
                if by_id.key? id
                    raise BuildError, "Duplicate document"
                end

                # If the document doesn't exist in the DB, create a new one
                unless doc = model_scope.find(id)
                    doc = model.new
                    doc._id = id
                end

                # If the document existed but it was dead, revive it
                doc.mark_alive

                # For each buildable attribute declared on the model
                model.buildable_attributes.each do |attr, opts|
                    if attrs.key?(attr)
                        value = attrs.delete(attr)
                        
                        # If a value was given for the attribute
                        if to_rebuild = opts[:rebuild]
                            # Call the builder method, if there is one
                            doc.instance_exec(value, &to_rebuild)
                        else
                            # Or just assign it directly
                            # (calling the setter directly does not work for Hash fields, this does)
                            doc.write_attribute(attr, value)
                        end
                    else
                        # If no value was given for the attribute, we need to reset it to its default value
                        # There are no partial updates, so if a value is missing, that means it has no value.
                        doc.__send__(:reset_attribute_to_default!, attr)
                        doc.write_attribute(attr, doc.__send__(attr)) # Mongoid sometimes ignores changes without this
                    end
                end

                attrs.each do |attr, _|
                    add_error(id, "'#{attr}' is not a recognized attribute")
                end

                unless doc.valid?
                    doc.errors.full_messages.each do |msg|
                        add_error(id, msg)
                    end
                end

                add(doc)
            end
        end

        def add_path(path)
            catch_errors(path) do
                id = id_from_path(path)
                catch_errors(id) do
                    add_attrs(id, Psych.load(store.read(path)))
                end
            end
        end

        def load
            paths.each do |path|
                add_path(path)
            end

            model_scope.alive.nin(id: by_id.keys).each do |doc|
                doc.mark_dead
                add(doc)
            end

            model.validate_collection(self)
        end

        def valid?
            errors.empty?
        end

        def docs
            by_id.values
        end

        def living_docs
            docs.select(&:alive?)
        end

        def changed_docs
            docs.select(&:changed?)
        end

        def commit!
            if valid?
                changed_docs.each(&:save!) unless dry?
            else
                raise BuildError, "Validation failed"
            end
        end

        def log_changes
            logger.info "Loading model #{model}#{" (dry run)" if dry?}"

            docs = changed_docs

            if docs.empty?
                logger.info "  no changes"
            else
                docs.each do |doc|
                    if !doc.persisted?
                        logger.info "  create '#{doc.id}'"
                    elsif doc.changed?
                        dead_before, dead_after = doc.changes['died_at']
                        if !dead_before && dead_after
                            logger.info "  delete '#{doc.id}'"
                        elsif dead_before && !dead_after
                            logger.info "  revive '#{doc.id}'"
                        else
                            logger.info "  update '#{doc.id}'"
                            doc.changes.each do |attr, (before, after)|
                                logger.info "    #{attr}: #{before.inspect} -> #{after.inspect}"
                            end
                        end
                    end
                end
            end
        end

        def log_errors
            errors.each do |e|
                logger.error("  #{e}")
            end
        end
    end
end
