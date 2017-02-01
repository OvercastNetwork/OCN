module CacheTestHelpers
    delegate :clear_request_cache, :unit_of_work,
             to: Cache::RequestManager
end
