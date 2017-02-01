class Module
    def base_name
        self.name.split(/::/).last
    end

    # All instances of this module
    def instances(&block)
        ::ObjectSpace.each_object(self, &block)
    end

    # All modules descended from this module
    def descendants
        if block_given?
            ::Module.instances do |mod|
                yield mod if mod <= self
            end
        else
            enum_for :descendants
        end
    end

    def abstract(*names)
        names.each do |name|
            define_method name do |*_|
                raise NotImplementedError, "Called abstract method '#{name}'"
            end
        end
    end

    def hybrid_methods(&block)
        unless @hybrid_method_module
            hm = @hybrid_method_module = Module.new
            include hm
            if is_a?(ActiveSupport::Concern)
                class_methods{ include hm }
            else
                extend hm
            end
        end

        @hybrid_method_module.module_eval(&block)
    end
end
