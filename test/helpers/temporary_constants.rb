module TemporaryConstants
    class << self
        def temporary_constants
            Thread.current[:temporary_constants]
        end
    end

    def before_setup
        Thread.current[:temporary_constants] = Hash.default{ Set[] }
        Thread.current[:temporary_constant_serial] = 0

        super
    end

    def after_teardown
        super

        TemporaryConstants.temporary_constants.each do |parent, names|
            parent.class_eval do
                names.each do |name|
                    remove_const name if const_defined? name
                end
            end
        end

        Thread.current[:temporary_constants] = nil
        Thread.current[:temporary_constant_serial] = nil
    end

    def new_constant_serial
        Thread.current[:temporary_constant_serial] += 1
    end

    def new_constant_name(prefix)
        "#{prefix}#{new_constant_serial}"
    end

    def new_constant(name = nil, value)
        name ||= new_constant_name("CONST")
        mod = self.class
        TemporaryConstants.temporary_constants[mod] << name.to_sym
        mod.class_eval do
            const_set(name, value)
        end
    end

    def new_class(name: nil, extends: Object, &block)
        new_constant(name || new_constant_name("Class"), Class.new(extends) do
            class_exec(&block) if block
        end)
    end
end

