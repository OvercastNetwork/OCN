
# A report about server performance/health
class ServerHealthReport < BaseMessage
    include ServerReport

    prefix 'minecraft'

    metric :ticks_per_second
    metric :average_tick_duration
    metric :maximum_tick_duration
end
