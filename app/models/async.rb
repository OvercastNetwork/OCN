module Async
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    module ClassMethods
        # Declare methods that are implicitly asynchronous
        def async_method(*names, worker: nil, timeout: nil)
            names.each do |async_name|
                sync_name = async_name.to_s.mangle_method_name(:sync)
                alias_method sync_name, async_name
                define_method async_name do |*arguments, &block|
                    async_send(sync_name, arguments: arguments, worker: worker, timeout: timeout, &block)
                end
            end
        end

        # Register a callback to be called asynchronously (by a queue worker).
        #
        # The event can be any type of callback already defined through ActiveSupport::Callbacks
        #
        # The callback must be a named instance method. Inline blocks are not supported
        # as they would be difficult to encode canonically in a serialized queue message.
        #
        # This method simply registers a normal callback that sends the message.
        # Any extra options are passed directly to #set_callback, which means
        # that :if and :unless can be used to decide if the message should be sent or not.
        #
        # Multiple async callbacks for the same event will run concurrently, so don't assume any
        # particular order, and be careful of race conditions.

        def after_event_async(event, method_name, worker: nil, timeout: nil, **opts)
            set_callback(event, :after, **opts) do
                async_send(method_name, worker: worker, timeout: timeout)
                true
            end
        end
    end # ClassMethods

    def async_send(method_name, arguments: [], worker: nil, timeout: nil, &block)
        block and raise ArgumentError, "Asynchronous method cannot take a block"
        Publisher::DIRECT.publish(
            InvokeModelMethod.new(
                method: method(method_name),
                arguments: arguments,
                worker: worker,
                expiration: timeout
            )
        )
        nil # TODO: return a promise/future type thing
    end

    # Return a proxy for this object that will invoke any method called asynchronously
    def async_proxy(worker: nil, timeout: nil)
        AsyncProxy.new(self, worker: worker, timeout: timeout)
    end

    class AsyncProxy
        def initialize(document, worker: nil, timeout: nil)
            @document = document
            @worker = worker
            @timeout = timeout
        end

        def method_missing(method_name, *arguments, &block)
            async_send(method_name, arguments: arguments, &block)
        end
    end
end
