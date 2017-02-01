# Adds two class-level declarations:
#
#     mattr_inherited :name
#
# defines a writable class attribute whos value is inherited by subclasses.
# Subclasses can override the value by assigning to the attribute. If a block
# is given, it is called to generate a default value.
#
#     mattr_inherited_hash :name
#
# defines a read-only class attribute containing a Hash whos entries are
# inherited by subclasses. The base class is initialized with an empty
# Hash, or the Hash returned from a block, if given. Each subclass gets
# an InheritedHash derived from its immediate superclass.

module InheritedAttributes
    extend ActiveSupport::Concern

    module ClassMethods
        def mattr_inherited(name, &block)
            base_class = self
            ivar_name = :"@#{name}"

            define_singleton_method name do
                if instance_variable_defined?(ivar_name)
                    instance_variable_get(ivar_name)
                elsif superclass <= base_class
                    superclass.__send__(name)
                elsif block
                    block.call
                end
            end

            define_singleton_method "#{name}=" do |value|
                instance_variable_set(ivar_name, value)
            end
        end

        def mattr_inherited_hash(name, &block)
            mattr_inherited_container(name, InheritedHash, Hash, &block)
        end

        def mattr_inherited_list(name)
            mattr_inherited_container(name, InheritedList, Array)
        end

        private

        def mattr_inherited_container(name, klass, base, &block)
            base_class = self
            ivar_name = :"@#{name}"

            define_singleton_method name do
                instance_variable_get(ivar_name) or instance_variable_set(
                    ivar_name,
                    if superclass <= base_class
                        klass.new(superclass.__send__(name))
                    elsif block
                        block.call
                    else
                        base.new
                    end
                )
            end
        end
    end
end
