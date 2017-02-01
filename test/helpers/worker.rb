# TODO: Make this work
module TestWorker
    extend ActiveSupport::Concern
    include Worker

    def sleep(t)
        if @test_thread == Thread.current
            Timecop.freeze(t)
            @test_time += t
            @test_mutex.synchronize do
                @test_condition.broadcast
            end
        else
            wake_time = @test_time + t
            while @test_time < wake_time
                @test_mutex.synchronize do
                    @test_condition.wait(@test_mutex)
                end
            end
        end
    end

    def run_startup
        @test_thread = Thread.current
        @test_time = 0.0
        @test_mutex = Mutex.new
        @test_condition = ConditionVariable.new

        super
    end

    def run_idle
        run_startup unless running?
        run_event until event_queue.empty?
    end
end
