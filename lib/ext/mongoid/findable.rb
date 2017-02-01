module Ext
    module Mongoid
        module Findable
            # Same as #find but always raises DocumentNotFound on failure
            def need(*ids)
                if (found = find(*ids)) && (ids.size == 1 || ids.size <= found.size)
                    found
                else
                    found = [*found]
                    klass = if respond_to? :klass
                        self.klass
                    else
                        self
                    end
                    raise ::Mongoid::Errors::DocumentNotFound.new(klass, ids, ids - found.map(&:_id))
                end
            end
        end
    end
end

::Mongoid::Findable.__send__(:include, ::Ext::Mongoid::Findable)
::Mongoid::Criteria::Findable.__send__(:include, ::Ext::Mongoid::Findable)
