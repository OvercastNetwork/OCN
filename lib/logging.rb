module Logging
    class SensibleFormatter < Logger::Formatter
        def initialize(show_name: true)
            super()
            @show_name = show_name
        end

        def call(severity, time, progname, msg)
            severity = severity.ljust(5, ' ')
            if progname && @show_name
                "#{time.utc.strftime("%Y-%m-%d %H:%M:%S")} #{severity} [#{progname}] #{msg}\n"
            else
                "#{time.utc.strftime("%Y-%m-%d %H:%M:%S")} #{severity} #{msg}\n"
            end
        end
    end

    class SensibleLogger < Logger
        def initialize(*args)
            super
            self.formatter = SensibleFormatter.new(show_name: false)
        end
    end

    # Logs everything to a string that you can access at any time through #out
    class StringLogger < SensibleLogger
        attr :out

        def initialize(out = nil)
            @out = out || ""
            super(StringIO.new(@out))
        end
    end

    LOGGER = ThreadLocal.new{ Rails.logger }

    class << self
        # Returns the default logger for the current thread,
        # or the given default if none is set for the thread.
        def logger(default: Rails.logger)
            if LOGGER.present?
                LOGGER.get
            else
                default
            end
        end

        # Yield to the block with the given logger as the default for this thread.
        def with_logger(logger, &block)
            LOGGER.with(logger, &block)
        end

        # Yield to the block with a new StringLogger as the current thread's
        # default logger, and return its captured output. The StringLogger is also
        # passed to the block.
        def capture
            logger = StringLogger.new
            with_logger logger do
                yield logger
            end
            logger.out
        end

        def stdout
            logger = SensibleLogger.new(STDOUT)
            with_logger logger do
                yield logger
            end
        end
    end
end
