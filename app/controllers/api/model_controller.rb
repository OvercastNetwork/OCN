module Api
    class ModelController < ApiController
        class << self
            attr_reader :model_class, :singular_name, :plural_name
            def controller_for(klass, singular: nil, plural: nil)
                singular ||= klass.base_name.underscore
                plural ||= singular.pluralize

                @model_class = klass
                @singular_name = singular.to_s
                @plural_name = plural.to_s
            end
        end

        delegate :model_class, :singular_name, :plural_name, to: 'self.class'

        def show
            respond model_instance.api_document
        end

        def index
            respond_with_message model_class.search_response(documents: model_instances)
        end

        def update
            attrs = document_param

            2.times do
                doc = begin
                    # Look for an existing document
                    model_instance
                rescue Mongoid::Errors::DocumentNotFound
                    # If doc doesn't exist, create a new one
                    set_model_instance(model_class.new(attrs))
                end

                # Update the relations first, so that any new ones are created
                # before we try to reference them.
                doc.update_relations!(attrs)

                begin
                    # Try to update the document and break out of the retry loop if successful
                    doc.update_attributes!(attrs)
                rescue Mongo::Error::OperationFailure => ex
                    if doc.new_record? && ex.message =~ /11000/
                        # If we tried to create a new document and got a duplicate key error (11000)
                        # then someone else probably created the same document after we looked for
                        # it, so try the whole process again. Give up if this happens twice in a row.
                        next
                    else
                        # In any other case, propagate the exception
                        raise
                    end
                else
                    after_update(doc)
                    break
                end
            end

            show
        end

        def update_multi
            reply = do_update_multi
            respond_with_message reply, status: if reply.failed == 0 then 200 else 400 end
        end

        protected

        def after_update(doc)
        end

        def do_update_multi(&block)
            created = updated = skipped = 0
            errors = {}
            tries = 10 # Failsafe, so we don't loop forever if the error doesn't go away

            updates = params[:documents].to_a

            until updates.empty?
                tries -= 1
                conflicts = []

                by_id = model_class.in(id: updates.map{|attrs| attrs['_id']}).index_by(&:id).mash{|k, v| [k.to_s, v] }

                updates.each do |attrs|
                    id = attrs['_id']
                    if obj = by_id[id]
                        before = obj.as_document.dup
                        obj.assign_attributes(attrs)
                        obj.normalize if obj.respond_to?(:normalize)

                        block[obj] if block

                        after = obj.as_document

                        if before == after
                            skipped += 1
                        elsif obj.save
                            updated += 1
                            after_update(obj)
                        else
                            errors[id] = obj.errors.messages
                        end

                    else
                        obj = model_class.new(attrs)
                        obj.normalize if obj.respond_to?(:normalize)

                        block[obj] if block

                        begin
                            obj.save and created += 1
                        rescue Mongo::Error::OperationFailure => ex
                            if ex.to_s =~ /E11000/ && tries > 0
                                # Duplicate key, most likely due to race condition. We will retry
                                conflicts << attrs
                            else
                                errors[id] = ex.to_s
                            end
                        else
                            after_update(obj)
                        end
                    end
                end

                updates = conflicts
            end

            reply = create_update_multi_response
            reply.created = created
            reply.updated = updated
            reply.skipped = skipped
            reply.failed = errors.size
            reply.errors = errors
            reply
        end

        def create_update_multi_response
            UpdateMultiResponse.new
        end

        def document_param
            if document = params[:document]
                doc_id = document['_id']
                uri_id = model_id_param
                if doc_id && uri_id && doc_id != uri_id
                    raise BadRequest, "Mismatched _id in URI and document"
                end
            end
            document
        end

        # Retrieve the model instance from the database and return it
        def lookup_model_instance
            model_param(model_class)
        end

        # Set the given document as the model instance
        def set_model_instance(doc)
            instance_variable_set("@#{singular_name}", doc)
        end

        # Retrieve and set the model instance
        def find_model_instance
            set_model_instance(lookup_model_instance)
        end

        # Return the model instance, retrieving it from the database if needed
        def model_instance
            instance_variable_get("@#{singular_name}") or find_model_instance
        end

        def model_criteria
            if ids = params[:ids]
                model_class.in(id: ids)
            elsif model_class < ApiSearchable
                model_class.search(params)
            else
                model_class.all
            end
        end

        def find_model_instances
            instance_variable_set("@#{plural_name}", model_criteria)
        end

        def model_instances
            instance_variable_get("@#{plural_name}") or find_model_instances
        end
    end
end
