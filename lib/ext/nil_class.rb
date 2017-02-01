module Ext
    module NilClass
        def to_bool
            false
        end
    end
end

::NilClass.__send__(:include, ::Ext::NilClass)
