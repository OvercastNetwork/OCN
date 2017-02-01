# Include this in any object and call #request_cache to get a Hash
# scoped to that object, that is cleared between requests.
#
# #object_id is used as the cache key, so that the object itself
# can be garbage collected.
#
# See also #Cache::RequestManager
#
# TODO: make this thread-safe, and easier to use outside of http requests
module RequestCacheable
    extend ActiveSupport::Concern

    class << self
        def request_cache_for(obj)
            Cache::RequestManager.get(obj.object_id){ {} }
        end

        def define_cached_attribute(cls, name, &block)
            name = name.to_sym

            cls.class_exec do
                define_method(name) do
                    request_cache.cache(name) do
                        instance_exec(&block)
                    end
                end

                define_method("#{name}_cached?") do
                    request_cache.key?(name)
                end

                define_method("#{name}=") do |value|
                    request_cache[name] = value
                end

                define_method("invalidate_#{name}!") do
                    request_cache.delete(name)
                end
            end
        end
    end

    hybrid_methods do
        def request_cache
            RequestCacheable.request_cache_for(self)
        end
    end

    class_methods do
        def attr_cached(name, &block)
            RequestCacheable.define_cached_attribute(self, name, &block)
        end

        def cattr_cached(name, &block)
            RequestCacheable.define_cached_attribute(singleton_class, name, &block)
        end
    end
end
