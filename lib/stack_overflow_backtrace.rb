# Install this hook to get backtraces for SystemStackError (stack overflow),
# which normally don't provide any backtrace before Ruby 2.2
# http://stackoverflow.com/questions/11544460/
#
# This will slow things down a lot, so only use it for debugging.
module StackOverflowBacktrace
    def self.install
        set_trace_func proc {
            |event, file, line, id, binding, classname|
            if event == "call"  && caller_locations.length > 500
                fail "stack level too deep"
            end
        }
    end
end
