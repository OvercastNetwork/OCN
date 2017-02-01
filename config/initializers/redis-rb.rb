options = {
    'production'    => { host: 'redis' },
    'staging'       => { host: 'redis-staging' },
    'development'   => { },
    'test'          => { port: 7480 },
}

REDIS = Redis.new(options[Rails.env])
