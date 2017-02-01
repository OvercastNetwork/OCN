module WorkerDelegate
    module ApiMethods
        attr_accessor :worker_delegate

        # Extend the real worker with the framework's API
        [:worker_id, :server, :config, :logger].each do |meth|
            define_method meth do
                self.worker_delegate.send(meth)
            end
        end
    end

    # Forward framework callbacks to the real worker
    [:reload, :before_fork, :after_start].each do |meth|
        define_method meth do
            @worker.send(meth) if @worker && @worker.respond_to?(meth)
        end
    end

    # Allocate the real worker, but don't #initialize it).
    # This is called in the child process after forking.
    def allocate_worker
        raise NotImplementedError, "Inheritor should implement this"
    end

    def run
        Rails.logger = logger
        me = self
        @worker = allocate_worker
        @worker.extend(ApiMethods)
        @worker.worker_delegate = me
        @worker.__send__(:initialize)
        @worker.run
    rescue => ex
        logger.error("Worker terminated with an exception, restarting after a short delay\n#{ex.class}: #{ex.message}\n#{ex.backtrace.join("\n")}")
        Raven.capture_exception(ex)
        retry unless error_stop_flag.wait_for_set(10)
    end

    def stop
        error_stop_flag.set!
        @worker.stop if @worker && @worker.respond_to?(:stop)
    end

    def error_stop_flag
        @error_stop_flag ||= ServerEngine::BlockingFlag.new
    end
end
