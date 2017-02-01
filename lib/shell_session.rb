class ShellSession
    include Loggable

    class CommandError < Exception
        attr_reader :command
        attr_reader :status
        attr_reader :output

        def initialize(command, status, output)
            @command, @status, @output = command, status, output
            super("Command returned non-zero status #{status}\n >>> #{command}\n#{output}")
        end
    end

    class << self
        def run(**opts, &block)
            new(**opts).run(&block)
        end
    end

    def initialize(cd: nil, log: true, print: false, tries: 1, retry_delay: 5.seconds)
        @cd = cd
        @log = log
        @print = print
        @tries = tries
        @retry_delay = retry_delay
    end

    def log?
        @log
    end

    def print?
        @print
    end

    def cmd(*args, print: print?, log: log?)
        input = args.join(' ')
        logger.info " ::: #{input}" if log
        print " ::: #{input}" if print

        output = ''
        IO.popen(args, err: [:child, :out]) do |io|
            io.each_line do |line|
                output << line

                logger.info "  #{line}" if log
                print "   #{line}" if print
            end
        end

        raise CommandError.new(args, $?.to_i, output) unless $?.success?

        output
    end

    def run(&block)
        if @cd
            Dir.chdir(@cd) do
                block.call(self)
            end
        else
            block.call(self)
        end
    rescue CommandError => ex
        @tries -= 1
        if @tries > 0
            msg = "Retrying command in #{@retry_delay} seconds (#{@tries} tries left)\n#{ex}"
            logger.warn msg if log?
            print msg if print

            sleep(@retry_delay)
            retry
        else
            raise
        end
    end
end
