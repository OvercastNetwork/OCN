module Ext
    module FalseClass
        def to_bool
            false
        end
    end
end

::FalseClass.__send__(:include, ::Ext::FalseClass)
