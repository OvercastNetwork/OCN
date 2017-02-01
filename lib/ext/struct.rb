module Ext
    module Struct
        module ClassMethods
            def build(**h)
                new(*h.symbolize_keys.values_at(*members))
            end
        end
    end
end

class Struct
    extend Ext::Struct::ClassMethods
end
