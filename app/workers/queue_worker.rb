
# Base for classes that respond to AMQP messages. Subclasses are instantiated by worker
# runners, typically in pools. The runners and their configurations are specific to each
# subclass. The #new method should generally have no parameters, unless the runner knows
# what to pass it.
#
# The consuming queue name is defined at the class level by calling #from_queue. Each
# instance will bind to this queue with its own Bunny connection. Options can also be
# passed to this method to override the global config, documented here:
# https://github.com/jondot/sneakers/wiki/Configuration#workers
#
# Incoming messages are dispatched to a method called "handle_<type>" where <type> is
# the value of the respective standard field in the AMQP metadata, after having #underscore
# called on it (so messages of type "CamelHumps" are dispatched to #handle_camel_humps).
# If the message has no type, or no handler method exists for its type, the message
# will be rejected.
#
# If a message has its content_type set to "application/json", the message payload
# is parsed as JSON, and the resulting object is keyword-splatted to the handler,
# otherwise the playload is passed as a single string argument. If the handler wants
# an entire JSON message in a single object, it can unsplat it i.e. handle_blob(**msg).
#
# If the handler accepts 2 arguments, the first one will be the message metadata. If the
# handler accepts 3 arguments, the first will be the delivery info, followed by the
# metadata. These structures are described in the Bunny documentation:
# http://rubybunny.info/articles/queues.html#handling_messages_with_a_block
#
# When using AMQP's explicit acknowledgement model (which is the default), messages will
# remain in the queue until a handler acks or rejects them. Handler methods should return
# one of the following symbols to do so:
#
#   :ack        Successfully handled the message
#   :reject     Failed to handle the message
#   :requeue    Failed, but requeue the message
#
# If the handler method raises, the message will be rejected.
#
# The #publish instance method can be used to publish a message through the worker's
# connection. The #publish class method does the same using the Sneakers global connection.
# Both methods call #prepare_publish on the message first, which serializes the message to
# JSON (unless the content_type is explicitly changed) and applies some default metadata.
# If the routing_key is not specified, the message will go to the worker's own queue.
# Worker subclasses may override #prepare_publish to do further processing.

module QueueWorker
    extend ActiveSupport::Concern
    include Worker

    QUEUE_DEFAULTS = {
        durable: true,
    }

    CONSUMER_DEFAULTS = {
        manual_ack: true,
        exclusive: false
    }

    module ClassMethods
        attr_reader :queue_name, :queue_options, :consumer_options

        def queue(queue, **options)
            @queue_name = queue.to_s
            @queue_options = QUEUE_DEFAULTS.merge(options)
        end

        def consumer(**options)
            @consumer_options = CONSUMER_DEFAULTS.merge(options)
        end

        def queue_options
            @queue_options ||= QUEUE_DEFAULTS
        end

        def consumer_options
            @consumer_options ||= CONSUMER_DEFAULTS
        end

        def topic_bindings
            @topic_bindings ||= []
        end

        def topic_binding(routing_key, **options)
            topic_bindings << [routing_key, options]
        end

        def message_handlers
            @message_handlers ||= Hash.default{ [] }
        end

        def handle(type, &block)
            message_handlers[type] = [*message_handlers[type], block]
        end

        def handle_messages(yes)
            @handle_messages = yes
        end

        def handle_messages?
            @handle_messages
        end
    end

    def direct
        Publisher::DIRECT
    end

    def fanout
        Publisher::FANOUT
    end

    def topic
        Publisher::TOPIC
    end

    def channel
        BUNNY.channel
    end

    def queue
        @queue
    end

    def queue_name
        self.class.queue_name
    end

    def queue_options
        self.class.queue_options
    end

    def consumer_options
        self.class.consumer_options
    end

    def manual_ack?
        consumer_options[:manual_ack]
    end

    def bind(exchange, **options)
        exchange = exchange.create_exchange(channel) if exchange.is_a? Publisher
        options[:routing_key] ||= queue_name
        logger.info "Binding to #{exchange.name} with key #{options[:routing_key]}"
        queue.bind(exchange, **options)
    end

    def topic_binding(routing_key, **options)
        routing_key = routing_key.name if routing_key.is_a? Module
        bind(topic, routing_key: routing_key, **options)
    end

    def initialize
        super

        @queue = begin
            channel.queue(queue_name, **queue_options)
        rescue Bunny::PreconditionFailed => ex
            logger.info "PRECONDITION_FAILED trying to declare queue '#{queue_name}', assuming a configuration change and recreating it\n#{ex.message}"

            channel.queue_delete(queue_name)
            channel.queue(queue_name, **queue_options)
        end

        @consumer_tag = channel.generate_consumer_tag

        bind(direct)
        bind(fanout)

        self.class.topic_bindings.each do |topic, opts|
            topic_binding(topic, **opts)
        end
    end

    def run_consumer
        logger.info "Consuming queue #{queue_name}"

        if self.class.handle_messages?
            queue.subscribe(consumer_tag: @consumer_tag,
                            on_cancellation: -> { error("Consumer cancelled") },
                            **consumer_options) do |delivery, meta, payload|
                schedule do
                    handle_unwrapped_message(delivery, meta, payload)
                end
            end
        end
    end

    def stop_consumer
        logger.info "Cancelling queue #{queue_name}"

        if self.class.handle_messages?
            channel.basic_cancel(@consumer_tag)
        end
    end

    def run
        run_consumer
        super
        stop_consumer
    end

    def handle_unwrapped_message(delivery, meta, payload)
        if msg = BaseMessage.deserialize(delivery, meta, payload)
            with_default_reply(msg) do
                dispatch_message(msg)
            end
        end

    rescue => ex
        message_error "Error wrapping AMQP message", type: meta.type, meta: meta, payload: payload, exception: ex
        manual_ack? and channel.acknowledge(delivery.delivery_tag, false)
    end

    def with_default_reply(msg)
        reply = yield

        if reply.is_a?(BaseMessage) && reply.is_reply?
            direct.publish(reply)
        elsif msg.needs_reply?
            reply_to(msg, success: true)
        end

    rescue => ex
        message_error "Error dispatching AMQP message", type: msg.class.name, meta: msg.meta, payload: msg.payload, exception: ex

        # Always ack TestErrors so they are not requeued
        ack_if_manual!(msg) if msg.is_a?(TestErrorMessage)

        if msg.needs_reply?
            reply_to(msg, success: false, error: "#{ex.class}: #{ex.message}")
        end
    end

    def dispatch_message(msg)
        ApiModel.with_protocol_version(msg.protocol_version) do
            reply = nil
            self.class.message_handlers.each do |type, handlers|
                if can_handle_message?(type, msg)
                    handlers.each do |handler|
                        logger.debug " <<< #{msg.class.name}"

                        begin
                            r = instance_exec(msg, &handler)

                            if r && r.is_a?(BaseMessage) && msg.needs_reply?
                                unless r.valid_reply_to?(msg)
                                    raise "Returned message is not a valid reply to request\n#{message_dump(r)}"
                                end
                                reply and raise "Multiple handlers tried to reply"
                                reply = r
                            end

                        rescue
                            file, line = handler.source_location
                            logger.info "Following exception was raised by handler at #{file}:#{line}"
                            raise
                        end
                    end
                end
            end
            reply
        end
    end

    def can_handle_message?(handler_type, message)
        if handler_type.is_a? Module
            message.is_a? handler_type
        else
            message.class.name == handler_type.to_s
        end
    end

    def pop_message(manual_ack: CONSUMER_DEFAULTS[:manual_ack])
        delivery, meta, payload = queue.pop(manual_ack: manual_ack)
        BaseMessage.deserialize(delivery, meta, payload) if delivery
    end

    def ack!(msg)
        channel.acknowledge(msg.delivery.delivery_tag, false)
    end

    def ack_if_manual!(msg)
        ack!(msg) if manual_ack?
    end

    def reject!(msg)
        channel.reject(msg.delivery.delivery_tag, false)
    end

    def requeue!(msg)
        channel.reject(msg.delivery.delivery_tag, true)
    end

    def reply_to(msg, success: true, error: nil)
        direct.reply_to(msg, success: success, error: error)
    end

    def message_error(text = "Error handling AMQP message", type: nil, meta: nil, payload: nil, exception: nil)
        error("#{text}\n#{message_dump(type: type, meta: meta, payload: payload)}", exception: exception)
    end

    def message_dump(msg = nil, type: nil, meta: nil, payload: nil)
        if msg
            type ||= msg.class.name
            meta ||= msg.meta
            payload ||= msg.payload
        end
        text = "TYPE: #{type || '(unknown message type)'}"
        meta and text = "#{text}\nMETADATA: #{meta.pretty_inspect}"
        payload and text = "#{text}\nPAYLOAD: #{payload.pretty_inspect}"
        text
    end

    included do
        handle_messages true

        handle PingMessage do |ping|
            logger.info("Replying to ping #{ping.meta.message_id} through queue #{ping.meta.reply_to}")
            ack_if_manual!(ping)

            if ping.reply_with == 'exception'
                raise "Test exception"
            elsif ping.reply_with == 'failure'
                Reply.new(request: ping, success: false, error: "Test failure")
            end
            # Let the default reply be sent
        end

        handle 'Sleep' do |msg|
            msg.seconds.downto(1).each do |n|
                logger.info("Sleeping for #{n} seconds")
                sleep(1)
            end
            logger.info("Waking up")
            ack_if_manual!(msg)
        end

        handle 'TestError' do |msg|
            raise msg.message || "Test error"
        end

        # Any QueueWorker can be sent async tasks - neato!
        handle BaseTask do |msg|
            msg.call
            ack_if_manual!(msg)
        end
    end
end
