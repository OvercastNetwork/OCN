
require 'thread'
require 'timeout'

# Concurrency primitive: contains a flag that is initially false.
# Any number of threads can block and wait for it to be set true.
# Not reusable.
class Barrier
    def initialize
        @lock = Mutex.new
        @cond = ConditionVariable.new
        @flag = false
    end

    # Wait for the flag to be set. If timeout is given, raise Timeout::Error
    # if the flag isn't set after the given number of seconds.
    def wait(timeout = nil)
        @lock.synchronize do
            unless @flag
                Timeout.timeout(timeout) do
                    @cond.wait(@lock)
                end
            end
        end
    end

    # Set the flag and resume any threads waiting on it
    def set
        @lock.synchronize do
            @flag = true
            @cond.broadcast
        end
    end
end
