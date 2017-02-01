module Cache
    module RequestManager
        class << self
            def cache
                @cache ||= {}
            end

            def clear_request_cache
                cache.clear
            end

            def store_request_item(key, value)
                cache[key] = value
            end

            def get_request_item(key)
                cache[key]
            end

            def del_request_item(key)
                cache.delete(key)
            end

            def cached?(key)
                cache.key?(key)
            end

            # Get a value cached for the current request, or call the
            # given block to initialize the value
            def get(key)
                if cached?(key)
                    cache[key]
                else
                    cache[key] = yield
                end
            end

            # Clear the cache, run the given block, and ensure that the
            # cache is cleared again after the block returns
            def unit_of_work
                clear_request_cache
                yield
            ensure
                clear_request_cache
            end
        end
    end
end
