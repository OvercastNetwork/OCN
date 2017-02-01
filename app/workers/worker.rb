require_dependency 'logging'

module Worker
    extend ActiveSupport::Concern

    include Loggable
    include ActiveSupport::Callbacks

    included do
        define_callbacks :dequeue
    end

    module ClassMethods
        def polling_tasks
            @polling_tasks ||= []
        end

        def poll(interval: nil, delay: nil, &block)
            raise ArgumentError.new("Need an interval or delay") unless interval || delay
            polling_tasks << [interval, delay, block]
        end

        def startup_tasks
            @startup_tasks ||= []
        end

        def startup(&block)
            startup_tasks << block
        end

        def shutdown_tasks
            @shutdown_tasks ||= []
        end

        def shutdown(&block)
            shutdown_tasks << block
        end
    end

    def initialize(*args)
        logger.formatter = Logging::SensibleFormatter.new
        logger.progname = self.class.name
        logger.info "Initializing #{self.class.name} in process #{$$}"
        super
    end

    def error(text = nil, exception: nil)
        logger.error(text) if text

        if exception
            logger.error("#{exception.class}: #{exception}\n#{exception.backtrace.join("\n")}")
            Raven.capture_exception(exception)
        else
            Raven.capture_message(text)
        end
    end

    # For easy mocking in tests
    def sleep(n)
        Kernel.sleep(n)
    end

    def event_queue
        @event_queue ||= Thread::Queue.new
    end

    def schedule(time: nil, delay: nil, &block)
        delay ||= 0
        delay += time - Time.now if time

        if delay > 0
            Thread.new do
                sleep(delay)
                event_queue << block
            end
        else
            event_queue << block
        end
    end

    def poll(interval: nil, delay: nil, &block)
        raise ArgumentError.new("Need an interval or delay") unless interval || delay

        if interval
            Thread.new do
                until @stop_flag
                    event_queue << block
                    sleep(interval) unless @stop_flag
                end
            end
        else
            repeating_block = lambda do
                unless @stop_flag
                    block.call
                    Thread.new do
                        sleep(delay)
                        event_queue << repeating_block
                    end
                end
            end
            event_queue << repeating_block
        end
    end

    def running?
        @running
    end

    def stop
        unless @shutting_down
            @shutting_down = true
            run_shutdown_tasks
            schedule{ @running = false }
        end
    end

    def run_startup_tasks
        self.class.startup_tasks.each do |block|
            schedule do
                instance_exec(&block)
            end
        end
    end

    def run_shutdown_tasks
        self.class.shutdown_tasks.each do |block|
            schedule do
                instance_exec(&block)
            end
        end
    end

    def run_polling_tasks
        self.class.polling_tasks.each do |interval, delay, block|
            poll(interval: interval, delay: delay) do
                instance_exec(&block)
            end
        end
    end

    def run_event
        Logging.with_logger(logger) do
            Cache::RequestManager.unit_of_work do
                event_queue.pop.call
            end
        end
    rescue => ex
        error(exception: ex)
    end

    def run_event_loop
        run_event while @running
    end

    def run_startup
        @running = true
        run_startup_tasks
        run_polling_tasks
    end

    def run
        run_startup
        run_event_loop
    end
end
