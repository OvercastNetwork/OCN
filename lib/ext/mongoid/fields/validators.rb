module Mongoid
    module Fields
        module Validators
            module Macro
                # Override field name validation to validate the alias rather than the name.
                def validate_name_with_alias_support(klass, name, options)
                    validate_name_without_alias_support(klass, options[:as] || name, options)
                end

                alias_method_chain :validate_name, :alias_support
            end
        end
    end
end
