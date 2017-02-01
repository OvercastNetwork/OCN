#!/usr/bin/env ruby

ENV['OCN_ROLE'] = 'worker'
require File.expand_path('../environment', __FILE__)

Raven.capture

module Factory
    include WorkerDelegate

    def allocate_worker
        Rails.application.run_after_fork_callbacks
        Box.local.workers[worker_id].allocate
    end
end

def resolve_path(path)
    path = File.join(Rails.root, path) if Pathname.new(path).relative?
    FileUtils.mkdir_p(File.dirname(path))
    path
end

def send_signal(signal, **options)
    if File.exists?(options[:pid_path])
        pid = File.read(options[:pid_path]).to_i
        Process.kill(signal, pid)
        0
    else
        STDERR.puts "Worker not running (no pid file at #{options[:pid_path]})"
        2
    end
rescue Errno::ESRCH
    STDERR.puts "Worker not running (no process #{pid})"
    3
end

parser = Trollop::Parser.new do
    banner "\n    worker.rb [options] [start|stop|restart]\n \n"
    opt :pid, "PID file", type: :string, default: "tmp/pids/worker.pid"
    opt :log, "Log file", type: :string, default: "log/worker.log"
    opt :log_level, "Log level", type: :string, default: 'INFO'
end

options = parser.parse
options[:pid_path] = resolve_path(options[:pid])
options[:log] = if ARGV[0]
                    resolve_path(options[:log])
                else
                    '-'
                end
options[:log_level] = Logger::Severity.const_get(options[:log_level])

case ARGV[0]
    when 'start'
        options[:daemonize] = true
    when 'stop'
        exit(send_signal('TERM', **options))
    when 'restart'
        if 0 == send_signal('USR1', **options)
            exit(0)
        else
            options[:daemonize] = true
        end
    when nil
    else
        parser.educate
        exit(1)
end

ServerEngine.create(
    nil,
    Factory,
    worker_type: 'process',
    workers: Box.local.workers.size,
    supervisor: true,
    restart_server_process: true,
    **options
).run
