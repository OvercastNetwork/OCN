
# Worker with a temporary queue that can be used e.g. for testing in IRB
class PingWorker
    include QueueWorker

    queue :test, durable: false
    topic_binding 'test'

    class << self
        # For each given routing_key, Send a PingMessage to the direct exchange,
        # and simultaneously wait for a #Reply from each of them. Print
        # the round-trip time on stdout, or an error message if it times out.
        def ping(*routing_keys, timeout: 5)
            PingMessage # Ensure this is loaded now because it doesn't seem to want to load in the thread

            if routing_keys.size > 1
                routing_keys.map do |routing_key|
                    Thread.new { ping(routing_key, timeout: timeout) }
                end.each(&:join)
            else
                ping = PingMessage.new(queue_name, routing_key: routing_keys[0])
                consumer = new(ping)
                Publisher::Direct.new.publish(ping)

                begin
                    Timeout.timeout(timeout) do
                        consumer.run
                    end
                rescue Timeout::Error
                    consumer.stop
                    puts "Timed out waiting for pong from #{routing_keys[0]} (#{timeout} seconds)"
                end
            end

            nil
        end
    end

    def initialize(ping)
        super()
        @ping = ping
        @time = Time.now
    end

    handle Reply do |pong|
        if pong.meta.correlation_id == @ping.meta.message_id
            puts "Pong from #{@ping.delivery.routing_key} in #{Time.now - @time} seconds"
            ack!(pong)
            stop
        end
    end
end
