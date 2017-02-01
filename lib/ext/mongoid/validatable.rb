module Mongoid
    module Validatable
        class UniquenessValidator < ActiveModel::EachValidator
            # Monkey-patch to respect primary_key option
            def to_validate(document, attribute, value)
                metadata = document.relations[attribute.to_s]
                if metadata && metadata.stores_foreign_key?
                    [ metadata.foreign_key, value && value[metadata.primary_key] ]
                else
                    [ attribute, value ]
                end
            end

            # Add the :among option, a criteria that limits the set of records in
            # which the field must be unique. Note that this is very different from
            # the :scope option, which just adds extra fields.
            def validate_root(document, attribute, value)
                return if (among = options[:among]) && !document.matches?(among.selector)

                klass = document.class

                while klass.superclass.respond_to?(:validators) && klass.superclass.validators.include?(self)
                    klass = klass.superclass
                end
                criteria = create_criteria(klass, document, attribute, value)
                criteria = criteria.merge(options[:conditions].call) if options[:conditions]

                if criteria.with(criteria.persistence_options).read(mode: :primary).exists?
                    add_error(document, attribute, value)
                end
            end

            def scope(criteria, document, _attribute)
                among = options[:among] and criteria = among.dup

                Array.wrap(options[:scope]).each do |item|
                    name = document.database_field_name(item)
                    criteria = criteria.where(item => document.attributes[name])
                end
                criteria.with(document.persistence_options)
            end
        end
    end
end
