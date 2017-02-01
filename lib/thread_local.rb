# Container for a thread-local value. Usage is similar to the Java version:
#
#     THINGY = ThreadLocal.new(123)
#
#     THINGY.get    # => 123
#
#     THINGY.set(456)
#     THINGY.get    # => 456
#
#     THINGY.with(789) do
#         THINGY.get    # => 789
#     end
#     THINGY.get    # => 456
#
class ThreadLocal
    # If an initial value is given, it will be returned from #get
    # whenever the current thread has no explicitly set value.
    #
    # The default is returned by #get when no value is set. If a
    # block is given, it will be called to create a default
    # value every time one is needed.
    def initialize(default = nil, &block)
        @key = :"ThreadLocal_#{object_id}"
        @presence_key = :"#{@key}_present"
        @initial = block || -> { default }
    end

    # Is a value currently set?
    def present?
        Thread.current[@presence_key]
    end

    def get
        if present?
            Thread.current[@key]
        else
            @initial.call
        end
    end

    def set(v)
        Thread.current[@presence_key] = true
        Thread.current[@key] = v
    end

    def clear
        Thread.current[@key] = nil
        Thread.current[@presence_key] = false
    end

    # Set to +value+, call block, restore previous state.
    # If a callable is given for +init+, it is called to generate the value.
    # If a callable is given for +after+, it is called with the value after
    # the previous state is restored.
    def with(value = nil, init: nil, after: nil)
        value && init and raise ArgumentError, "pass value or init, not both"
        value ||= init.call

        old_value = Thread.current[@key]
        old_presence = Thread.current[@presence_key]

        set(value)

        yield

    ensure
        Thread.current[@key] = old_value
        Thread.current[@presence_key] = old_presence

        after.call(value) if after
    end

    # Similar to the +with+ method, except the value is only set if there
    # is none present already. If +init+ is given, it will only be called
    # when the value is actually set. The block is always called.
    def debounce(value = nil, init: nil, after: nil, &block)
        if present?
            block.call
        else
            with(value, init: init, after: after, &block)
        end
    end
end
