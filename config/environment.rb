require 'socket'

# Load the rails application
require File.expand_path('../application', __FILE__)

# Load this first, because other initializers depend on it
require File.expand_path('../initializers/load_ext', __FILE__)

# The worker uses a daemon wrapper that captures STDOUT to the log file
if PGM::Application.ocn_role == 'worker'
    Rails.logger = Logger.new(STDOUT)
    Rails.logger.level = Logger::INFO
end

# Horrible hack required because too much stuff breaks if we set the
# actual environment to anything besides 'production' or 'development'
STAGING = (ENV['OCN_BOX'] || Socket.gethostname.partition(/\./).first) =~ /^chi01/
PRODUCTION = Rails.env.production? && !STAGING

# Initialize the rails application
PGM::Application.initialize!

if PGM::Application.ocn_role == 'worker'
    Rails.logger.formatter = Logging::SensibleFormatter.new
end

PGM::Application.configure do
    config.peek.adapter = :redis, {
        :client => REDIS,
        :expires_in => 30.minutes
    }

    # Log database queries
    config.query_logging = false

    config.site_base_url = "https://#{ORG::DOMAIN}"
    config.avatar_base_url = "https://avatar.#{ORG::DOMAIN}"

    # Use localhost for avatar URLs
    config.local_avatars = false

    config.global_per_page = 20

    # Time do display "formerly blah" after a username change
    config.username_change_transition_time = 30.days

    config.gamemodes = {
        "Project Ares" => ["TDM", "CTW", "DTC", "DTM", "KOTH", "Mixed"],
        "Blitz" => ["Classic", "Rage"],
        "Ghost Squadron" => ["GS"],
    }

    config.gamemodes_short = {
        "pa" => "Project Ares",
        "blitz" => "Blitz",
        "gs" => "Ghost Squadron",
    }
    config.gamemodes_short_inv = config.gamemodes_short.invert

    config.gamemodes_folders = {
        "pa" => ["/TDM", "/CTW", "/DTC", "/DTM", "/KOTH", "/Mixed"],
        "blitz" => ["Blitz/Classic", "Blitz/Rage"],
        "gs" => ["Blitz/GS"],
    }

    config.after_initialize do
        unless config.query_logging
            Mongo::Logger.logger = Rails.logger.clone
            Mongo::Logger.logger.level = Logger::INFO
        end
    end
end
