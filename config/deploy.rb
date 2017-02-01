require 'bundler/capistrano'
require 'rvm/capistrano'
require 'capistrano-unicorn'
load 'deploy/assets'

set :stages, %w(production staging)
set :default_stage, 'staging'
require 'capistrano/ext/multistage'

set :rvm_ruby_string, "ruby-2.1.5"
set :rvm_type, :system

set :application, "ocn"
set :repository, "..."

set :scm, :git
set :deploy_to, "/home/deploy/apps/ocn"
set :user, 'deploy'
set :git_enable_submodules, 1
set :use_sudo, false

set :worker_user, 'minecraft'
set :worker_log, "/minecraft/logs/worker/worker.log"
set :worker_pid, "/minecraft/tmp/pids/worker.pid"


UNICORNS = %i[octc avatar api]

default_environment['rvmsudo_secure_path'] = '0'
ssh_options[:forward_agent] = true

after 'deploy:update', 'deploy:cleanup'
after 'deploy:restart', 'unicorn:duplicate'


##########
# Assets #
##########

namespace :deploy do
    namespace :assets do
        def should_update_assets?
        #     from = source.next_revision(current_revision)
        #     capture("cd #{latest_release} && #{source.local.log(from)} app/assets/ | wc -l").to_i > 0
        # rescue
            true
        end

        task :precompile, :roles => :web, :except => { :no_release => true } do
            if should_update_assets?
                run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assets:precompile}
            else
                logger.info "Skipping asset pre-compilation because there were no asset changes"
            end
        end
    end
end


###########
# Unicorn #
###########

namespace :unicorn do
    def set_role(role)
        ENV['OCN_ROLE'] = role.to_s
        set :unicorn_bundle, "OCN_ROLE=#{role} bundle" # HACK because the value set above does not seem to make it into the Unicorn process
        set :unicorn_pid, "#{fetch(:deploy_to)}/shared/pids/#{role}.pid"
        set :unicorn_roles, [role]
    end

    desc 'Duplicate Unicorn'
    task :duplicate, :roles => unicorn_roles, :except => {:no_release => true} do
        # Start two Unicorn pools, using this env var to control their configuration.
        # This var is also used during route loading to choose which routes to use.
        UNICORNS.each do |role|
            set_role(role)
            run duplicate_unicorn
        end
    end

    desc 'Start Unicorn master process'
    task :start, :roles => unicorn_roles, :except => {:no_release => true} do
        UNICORNS.each do |role|
            set_role(role)
            run start_unicorn
        end
    end

    desc 'Stop Unicorn'
    task :stop, :roles => unicorn_roles, :except => {:no_release => true} do
        UNICORNS.each do |role|
            set_role(role)
            run kill_unicorn('QUIT')
        end
    end
end


##########
# Worker #
##########

after 'deploy:restart', 'worker:restart'

namespace :worker do
    def run_worker(action, verify: true)
        user = fetch(:worker_user)
        pid = fetch(:worker_pid)
        log = fetch(:worker_log)

        cmd = %Q[cd #{latest_release} && rvmsudo -u #{user} bundle exec config/worker.rb #{action} --pid #{pid} --log #{log}]
        cmd << %Q[ || true] unless verify
        run cmd
    end

    desc "Start worker daemon"
    task :start, roles: [:worker] do
        run_worker 'start'
    end

    desc "Stop worker daemon"
    task :stop, roles: [:worker] do
        run_worker 'stop'
        sleep(5) # TODO: proper wait for workers to terminate
    end

    desc "Restart worker daemon"
    task :restart, roles: [:worker] do
        run_worker 'stop', verify: false
        sleep(5)
        run_worker 'start'
    end
end

task :invoke_as do
    user = fetch(:user)
    begin
        set :user, ENV["USER"]
        invoke
    ensure
        set :user, user
    end
end

# Test task
task :uname do
    run "uname -a"
end
