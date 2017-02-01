module Mongoid
    module Fields
        module ClassMethods
            def metadata(attr)
                attr = attr.to_s
                relations[attr] || field_by_name(attr) or
                    raise TypeError, "#{self} has no field or relation named '#{attr}'"
            end

            def assert_field(*attrs)
                attrs.each do |attr|
                    unless field_by_name(attr)
                        raise TypeError, "#{self} has no field named '#{attr}'"
                    end
                end
            end

            def assert_field_or_relation(*attrs)
                attrs.each do |attr|
                    metadata(attr)
                end
            end

            # Lookup a field by name or alias
            def field_by_name(name)
                name = name.to_s
                fields.values.find{|f| name == (f.options[:as] || f.name).to_s }
            end
        end
    end
end
