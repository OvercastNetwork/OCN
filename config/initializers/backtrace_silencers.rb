# Be sure to restart your server when you modify this file.

# You can add backtrace silencers for libraries that you're using but don't wish to see in your backtraces.
# Rails.backtrace_cleaner.add_silencer { |line| line =~ /my_noisy_library/ }

# You can also remove all the silencers if you're trying to debug a problem that might stem from framework code.
# Rails.backtrace_cleaner.remove_silencers!

require Rails.root.join('lib/backtrace_cleaners')

Rails.backtrace_cleaner.add_filter do |line|
    BacktraceCleaners.clean_line(line)
end
