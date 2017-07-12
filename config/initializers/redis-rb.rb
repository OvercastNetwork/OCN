options = {
    'production'    => { host: 'redis' },
    'staging'       => { host: 'redis' }, #{ host: 'redis-staging' },
    'development'   => { host: 'redis' },
    'test'          => { host: 'redis', port: 7480 },
}

REDIS = Redis.new(options[Rails.env])
