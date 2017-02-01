
# Poll the server_status queue for reports and forward them to DataDog
class ServerReportWorker
    include QueueWorker

    # Discard messages older than 1 minute
    queue :server_status, durable: false, arguments: { 'x-message-ttl' => 60000 }
    handle_messages false

    poll delay: 10.seconds do
        # Pull all messages out of the queue and build a set of server_ids to prefetch
        server_ids = Set.new
        messages = []
        while msg = pop_message
            if msg.respond_to? :datadog_points
                messages << msg
                server_ids.add(msg.server_id) if msg.respond_to? :server_id
            end
            ack!(msg)
        end

        # Prefetch servers (to the identity map)
        Server.find(*server_ids)

        # Generate DataDog points and combine them into batches with identical options
        #   [metric, options] -> [points]
        batches = Hash.default{ [] }
        messages.each do |msg|
            options = msg.datadog_options
            msg.datadog_points.each do |metric, point|
                batches[[metric, options]] << point
            end
        end

        # Send each batch with a single API call
        Dog.client.batch_metrics do
            batches.each do |(metric, options), points|
                Dog.client.emit_points(metric, points, options)
            end
        end
    end
end
