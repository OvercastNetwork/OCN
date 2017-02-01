require_dependency 'logging'

module LoggingWorker
    include Loggable

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
end
