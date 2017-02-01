class Publisher
    include Loggable

    class ReplyTimeout < TimeoutError
    end

    EXCHANGE_DEFAULTS = {
        durable: true
    }

    DEFAULT_REPLY_TIMEOUT = 30.seconds

    def initialize(type:, exchange:, channel: nil, **options)
        @exchange_type = type
        @exchange_name = exchange
        @exchange_options = options
        @channel = channel
    end

    delegate :channel, :reply_queue, to: BUNNY

    def create_exchange(ch)
        if ch == channel && @exchange
            exchange
        else
            Bunny::Exchange.new(channel, @exchange_type, @exchange_name, **EXCHANGE_DEFAULTS.merge(@exchange_options))
        end
    end

    def exchange
        @exchange ||= create_exchange(channel)
    end

    def publish(msg, **opts)
        msg = BaseMessage.create(payload: msg, **opts) unless msg.is_a? BaseMessage
        opts = msg.publish_options.merge(opts)
        opts[:routing_key] = opts[:routing_key].to_s

        # logger.debug " >>> #{msg.class.name}"
        logger.debug " >>> #{msg.class.name} OPTIONS: #{opts}\nMESSAGE: #{msg.inspect}"

        exchange.publish(msg.serialize, **opts)
    end

    def await_reply(msg, timeout: nil)
        logger.debug "Waiting for reply to message #{msg.meta.message_id} from reply queue #{reply_queue.name}"

        timeout ||= DEFAULT_REPLY_TIMEOUT
        return_container = []
        ctag = channel.generate_consumer_tag

        begin
            Timeout.timeout(timeout, ReplyTimeout) do
                reply_queue.subscribe(consumer_tag: ctag, manual_ack: false, exclusive: true, block: true) do |delivery, meta, payload|
                    reply = BaseMessage.deserialize(delivery, meta, payload)

                    logger.debug " {{{ #{reply.inspect}"

                    if msg.meta.message_id == reply.meta.correlation_id
                        return_container[0] = if block_given?
                                                  yield reply
                                              else
                                                  reply
                                              end
                        channel.basic_cancel(ctag) # This seems to exit the block, so do it last
                    end
                end
            end
        rescue ReplyTimeout
            raise ReplyTimeout, "Timed out (#{timeout} seconds) waiting for reply to message #{msg.meta.message_id} from queue #{reply_queue.name}"
        ensure
            channel.basic_cancel(ctag)
        end

        return_container[0]
    end

    def request(msg, timeout: nil, **opts, &block)
        publish(msg, **opts)
        await_reply(msg, timeout: timeout, &block)
    end

    def ping(routing_key = '', timeout: nil, **opts, &block)
        request(PingMessage.new, timeout: timeout, routing_key: routing_key, **opts, &block)
    end

    def sleep(seconds: 5, **opts)
        publish({seconds: seconds}, type: 'Sleep', **opts)
    end

    def test_error(message: nil, **opts)
        publish({message: message}, type: 'TestError', **opts)
    end

    DIRECT_NAME = 'ocn.direct'
    FANOUT_NAME = 'ocn.fanout'
    TOPIC_NAME  = 'ocn.topic'

    class Direct < Publisher
        def initialize(channel: nil, **options)
            options = {
                type: :direct,
                exchange: DIRECT_NAME,
                durable: true
            }.merge(options)
            super(channel: channel, **options)
        end

        # Send a generic reply to a message indicating success or failure.
        # The given request message must have a reply_to header set to the
        # return queue name.
        def reply_to(request, success: true, error: nil, **opts)
            if request.meta.reply_to
                publish(Reply.new(request: request, success: success, error: error), **opts)
            else
                logger.error "Cannot reply to #{request.class} with no reply_to header"
            end
        end
    end

    class Fanout < Publisher
        def initialize(channel: nil, **options)
            options = {
                type: :fanout,
                exchange: FANOUT_NAME,
                durable: true
            }.merge(options)
            super(channel: channel, **options)
        end
    end

    class Topic < Publisher
        def initialize(channel: nil, **options)
            options = {
                type: :topic,
                exchange: TOPIC_NAME,
                durable: true
            }.merge(options)
            super(channel: channel, **options)
        end

        def publish_topic(message, **opts)
            opts = {
                routing_key: message.class.type_name
            }.merge(opts)

            publish(message, **opts)
        end
    end

    DIRECT = Direct.new
    FANOUT = Fanout.new
    TOPIC  = Topic.new
end
