module Ext
    module Mongoid
        module Persistable
            module CustomAtomicOperations
                # Perform a custom operation through Mongoid's atomic update system.
                # This means it will work with an #atomically block.
                #
                # @param [String] operator A Mongo update operator such as '$inc', '$max', etc.
                # @param [Hash] fields Operands for the operator
                #
                # The block is used to update the document in memory. For each operand,
                # the block is called with the current field value, and the operand value,
                # and must return the new value for the field.

                def atomic_operation(operator, fields, &block)
                    prepare_atomic_operation do |operations|
                        process_atomic_operations(fields) do |field, value|
                            block and attributes[field] = block.call(attributes[field], value)
                            operations[atomic_attribute_name(field)] = value.mongoize
                        end
                        { operator => operations }
                    end
                end

                def atomic_min(fields)
                    atomic_operation('$min', fields) do |current, operand|
                        [current, operand].min
                    end
                end

                def atomic_max(fields)
                    atomic_operation('$max', fields) do |current, operand|
                        [current, operand].max
                    end
                end
            end

            module NestedAtomically
                include ::Mongoid::Persistable

                # Allow #atomically blocks to be nested
                def atomically
                    if @atomic_updates_to_execute
                        yield(self) if block_given?
                    else
                        super
                    end
                end
            end
        end
    end
end

::Mongoid::Persistable.__send__(:include, ::Ext::Mongoid::Persistable::CustomAtomicOperations)
::Mongoid::Document.__send__(:include, ::Ext::Mongoid::Persistable::NestedAtomically)
