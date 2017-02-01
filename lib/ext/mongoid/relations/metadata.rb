module Ext
    module Mongoid
        module Relations
            module Metadata
                attr_accessor :default_val

                # Mimic the default functionality for fields (except the value is not serialized)
                def eval_default(doc)
                    if default_val.respond_to? :call
                        doc.instance_exec(&default_val)
                    else
                        default_val
                    end
                end
            end
        end
    end
end

::Mongoid::Relations::Metadata.__send__(:include, ::Ext::Mongoid::Relations::Metadata)
