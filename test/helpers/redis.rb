module RedisSetupAndTeardown
    def before_setup
        REDIS.client.port == Redis::Client::DEFAULTS[:port] and raise "Refusing to run tests because Redis is using the default port"
        REDIS.flushall
        super
    end

    def after_teardown
        super
        REDIS.flushall
    end
end
