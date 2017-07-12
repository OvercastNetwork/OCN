module BUNNY
    CONFIG = {
        production: -> {
            {
                host: "rabbit" ,
                user: "admin",
                password: "admin"
            }
        },
        development: -> {
            {
                host: "rabbit",
                user: "admin",
                password: "admin"
            }
        },
        test: -> {
            {
                host: "localhost",
                port: 6783,
                user: "guest",
                password: "guest"
            }
        }
    }

    class << self
        def process_local
            @process_local ||= {}
            @process_local[$$] ||= {}
        end

        def configuration
            config = CONFIG[Rails.env.to_sym]
            config = config.call if config.respond_to? :call
            config.to_h
        end

        def create_session
            Bunny.new(**configuration).start
        end

        def create_reply_queue
            queue = channel.queue('', exclusive: true, arguments: { 'x-message-ttl' => 60000 })
            queue.bind(Publisher::DIRECT.exchange, routing_key: queue.name)
            queue
        end

        def session
            process_local[:session] ||= create_session
        end

        def channel
            unless process_local[:channel] && process_local[:channel].open?
                process_local[:channel] = session.create_channel
            end
            process_local[:channel]
        end

        # Channel specific queue used to receive RPC replies
        def reply_queue
            process_local[:reply_queue] ||= create_reply_queue
        end
    end
end
