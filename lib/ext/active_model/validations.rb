module ActiveModel
    # Monkey-patch EachValidator to add dotted path support.
    #
    # Attribute names provided for validation can use dot notation
    # to refer to deeply nested fields. This works with embedded
    # Mongoid::Documents and with fields of type Hash or Array.
    # Arrays elements are referred to by index e.g. 'things.2'
    #
    # Use '*' as a path component to validate all elements in
    # a collection.

    class EachValidator
        def validate(record)
            attributes.each do |attribute|
                nodes = attribute.to_s.split(/\./)
                validate_paths(record, nil, record, nodes)
            end
        end

        def validate_paths(record, name, value, nodes)
            if nodes.empty?
                unless (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
                    if record.respond_to?(name)
                        validate_each(record, name, value)
                    else
                        # HACK: Vaidators will sometimes try to get the value by calling
                        # the attribute name as a method on the record. We work around this by
                        # temporarily defining that method if it doesn't already exist.
                        begin
                            record.define_singleton_method(name) { value }
                            validate_each(record, name, value)
                        ensure
                            record.singleton_class.__send__(:remove_method, name)
                        end
                    end
                end
            else
                node, *tail = nodes
                if value.is_a? Mongoid::Document
                    if node == '*'
                        # All attributes on a Mongoid::Document
                        value.attributes.keys.each do |key|
                            validate_node(record, name, key, value.read_attribute_for_validation(key), tail)
                        end
                    else
                        # Single Mongoid::Document attribute
                        validate_node(record, name, node, value.read_attribute_for_validation(node), tail)
                    end
                elsif value.respond_to? :to_hash
                    value = value.to_hash.stringify_keys
                    if node == '*'
                        # All entries of a Hash-like object
                        value.each do |k, v|
                            validate_node(record, name, k, v, tail)
                        end
                    else
                        # Single Hash entry by key
                        validate_node(record, name, node, value[node], tail)
                    end
                elsif node == '*' && value.is_a?(Enumerable)
                    # All elements of an Enumerable
                    value.each_with_index do |e, i|
                        validate_node(record, name, i, e, tail)
                    end
                elsif node =~ /\A\d+\z/ && value.respond_to?(:to_ary)
                    # Single Array entry by index
                    validate_node(record, name, node, value[node.to_i], tail)
                elsif value.respond_to? node
                    # Named method on any object
                    validate_node(record, name, node, value.__send__(node), tail)
                else
                    # Give up
                    record.errors.add(name, "don't know how to read attribute '#{node}' from type #{value.class}")
                end
            end
        end

        def validate_node(record, name, node, value, tail)
            validate_paths(record, [name, node].compact.join('.'), value, tail)
        end
    end

    module Validations
        module HelperMethods
            # Convert a #validates keyword to a validator class e.g. :presence => PresenceValidator
            def resolve_validator_class(name)
                name = "#{name.to_s.camelize}Validator"

                begin
                    validator = name.include?('::') ? name.constantize : const_get(name)
                rescue NameError
                    raise ArgumentError, "Unknown validator: '#{name}'"
                end

                validator
            end

            # Instantiate a validator in the same way as #validates
            def create_validator(name, options, **extra)
                resolve_validator_class(name).new(_parse_validates_options(options).merge(extra))
            end

            def validates_elements_of(*names, **options)
                validates_with(ElementsValidator, options.merge(attributes: names))
            end
        end

        # Validates the individual elements of an Enumerable field using any validators
        #
        #     validates :things, elements: {presence: true, inclusion: {in: VALID_THINGS}}
        #
        #     validates_elements_of :things, presence: true, inclusion: {in: VALID_THINGS}
        #
        class CollectionValidator < ActiveModel::EachValidator
            def initialize(options)
                super
                klass = options.delete(:class)
                options.is_a?(Hash) or raise ArgumentError, "ElementsValidator options must be a Hash"
                @validators = options.map do |name, subopts|
                    klass.create_validator(name, subopts, class: klass, attributes: attributes)
                end
            end

            # Given the name and value of a collection field on a record,
            # yields (element_name, element_value) for each element in the collection.
            # Each element_name should include the field name.
            def each_element(record, name, value)
                raise NotImplementedError
            end

            def validate_each(record, name, value)
                if value.is_a? Enumerable
                    @validators.each do |validator|
                        each_element(record, name, value) do |element_name, element_value|
                            validator.validate_each(record, element_name, element_value)
                        end
                    end
                else
                    unless value.nil? && options[:allow_nil]
                        record.errors.add name, "Must be Enumerable (was #{value.class})"
                    end
                end
            end
        end

        class ElementsValidator < CollectionValidator
            def each_element(record, name, value)
                value.each_with_index do |e, i|
                    yield "#{name}[#{i}]", e
                end
            end
        end

        class HashValuesValidator < CollectionValidator
            def each_element(record, name, value)
                value.each do |k, v|
                    yield "#{name}.#{k}", v
                end
            end
        end

        # Checks that belongs_to fields with a value actually refer to something that exists
        class ReferenceValidator < ActiveModel::EachValidator
            def initialize(options)
                # If the FK is invalid, the accessor will return nil, which would cause
                # the allow_nil logic in the superclass to skip the validation entirely,
                # so we have to handle allow_nil ourselves.
                @allow_nil = options.delete(:allow_nil)
                super
            end

            def validate_each(record, attribute, value)
                rel = record.relations[attribute.to_s]

                klass = if rel.polymorphic?
                    if klass_name = record[rel.inverse_type]
                        begin
                            klass_name.constantize
                        rescue NameError
                            record.errors.add attribute, "refers to unknown type #{klass_name}"
                        end
                    else
                        record.errors.add attribute, "is a polymorphic relation with a foreign key but no type name"
                    end
                else
                    rel.klass
                end

                keys = if rel.many?
                    record[rel.foreign_key].to_a
                else
                    key = record[rel.foreign_key]

                    if key.nil?
                        unless @allow_nil
                            record.errors.add attribute, "cannot be nil"
                        end
                        return
                    end

                    [key]
                end

                if klass
                    # Query without scoping, in case related object is soft-deleted
                    keys -= klass.unscoped.in(rel.primary_key => keys).pluck(rel.primary_key)
                    keys.each do |key|
                        record.errors.add attribute, "refers to a #{klass} with #{rel.primary_key}=#{key.inspect} which does not exist"
                    end
                end
            end
        end

        class TimeValidator < ActiveModel::EachValidator
            def validate_each(record, attr, value)
                value.respond_to?(:to_time) or record.errors.add(attr, "must have a time value")

                [*options[:before]].each do |op|
                    op_label, op_value = eval_operand(record, op)
                    op_value.nil? || value <= op_value or record.errors.add(attr, "must be earlier than #{op_label}")
                end

                [*options[:after]].each do |op|
                    op_label, op_value = eval_operand(record, op)
                    op_value.nil? || op_value <= value or record.errors.add(attr, "must be later than #{op_label}")
                end
            end

            def eval_operand(ctx, op)
                if op.is_a?(Proc)
                    value = if op.arity > 0
                        op.call(ctx)
                    else
                        op.bind(ctx)
                        op.call
                    end
                    [value, value]
                elsif op.is_a?(Symbol)
                    [op, ctx.send(op)]
                else
                    [op, op]
                end
            end
        end

        class EmailValidator < ActiveModel::EachValidator
            REGEX = /\A[^@\s]+@[^.@\s]+\.[^@\s]+\z/
            def validate_each(record, attr, value)
                unless value =~ REGEX
                    record.errors.add attr, "is not a valid email address"
                end
            end
        end

        # You would think there would already be a way to do this, but there isn't.
        # Rails has no validator that checks for nil without also checking for
        # something else. PresenceValidator fails on blank strings, unless you
        # give it allow_blank: true, in which case it also allows nil i.e. it
        # does nothing at all.
        class NotNilValidator < ActiveModel::EachValidator
            def validate_each(record, attr, value)
                if value.nil?
                    record.errors.add attr, "cannot be nil"
                end
            end
        end

        # Check for the anonymous user aka User.anonymous_user
        class RealUserValidator < ActiveModel::EachValidator
            def validate_each(record, attr, value)
                if !value.is_a? User
                    record.errors.add attr, "must be a user"
                elsif value.anonymous?
                    record.errors.add attr, "cannot be anonymous"
                end
            end
        end

        class ChatColorValidator < ActiveModel::EachValidator
            def validate_each(record, attr, value)
                unless ChatColor.parse(value)
                    record.errors.add attr, "is an unknown color '#{value}'"
                end
            end
        end
    end
end
