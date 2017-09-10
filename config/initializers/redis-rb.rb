REDIS_HOST = ENV['REDIS_HOST'] || 'localhost'

options = {
    'production'    => { host: REDIS_HOST },
    'staging'       => { host: REDIS_HOST }, #{ host: 'redis-staging' },
    'development'   => { host: REDIS_HOST },
    'test'          => { host: REDIS_HOST, port: 7480 },
}

REDIS = Redis.new(options[Rails.env])
