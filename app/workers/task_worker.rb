class TaskWorker
    include QueueWorker

    queue :tasks
    consumer manual_ack: false
end
