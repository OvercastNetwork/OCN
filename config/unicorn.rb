role = ENV['OCN_ROLE'] or raise "Missing OCN_ROLE"

root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
pids = "#{root}/tmp/pids"
logs = "#{root}/log"

pid "#{pids}/#{role}.pid"
stderr_path "#{logs}/unicorn.err.log"
timeout 30          # restarts workers that hang for 30 seconds
preload_app true

case role
    when 'octc'
        listen 3000
        worker_processes 20
    when 'avatar'
        listen 3005
        worker_processes 10
    when 'api'
        listen 3010
        worker_processes 10
    else
        raise "Weird role: #{role}"
end

# kills old unicorns when the new workers are ready to spawn
before_fork do |server, worker|
    old_pid = "#{pids}/#{role}.pid.oldbin"
    if File.exists?(old_pid) && server.pid != old_pid
        begin
            Process.kill("QUIT", File.read(old_pid).to_i)
        rescue Errno::ENOENT, Errno::ESRCH
            # someone else did our job for us
        end
    end
end

after_fork do |server, worker|
    Rails.application.run_after_fork_callbacks
end
