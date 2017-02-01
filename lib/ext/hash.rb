module Ext
    module Hash
        module ClassMethods
            # Similar to #new but the block form calls the block with
            # only the key, and adds the returned value to the hash.
            def default(value = nil, &block)
                if block_given?
                    new{|h, k| h[k] = block[k] }
                else
                    new(value)
                end
            end
        end

        module InstanceMethods
            # Yield to the block and assign the returned value to the given
            # key, but only if the key meets the filter conditions. If only
            # is given, the key must be in it. If except is given, the key
            # must not be in it.
            def filter(key, only: nil, except: nil)
                if (only.nil? || only.to_a.include?(key)) && (except.nil? || !except.to_a.include?(key))
                    self[key] = yield
                end
            end

            def without(*keys)
                h = {}
                each{|k, v| h[k] = v unless keys.include?(k) }
                h
            end

            def changes(that, deep: false)
                delta = {}
                [*keys, *that.keys].uniq.each do |key|
                    a = self[key]
                    b = that[key]
                    if a != b
                        delta[key] = if deep && a.respond_to?(:to_hash) && b.respond_to?(:to_hash)
                            a.to_hash.changes(b.to_hash)
                        else
                            [a, b]
                        end
                    end
                end
                delta
            end

            def explode
                flat = []
                each do |k, v|
                    if v.respond_to?(:to_hash)
                        v.to_hash.explode.map do |a|
                            flat << [k, *a]
                        end
                    else
                        flat << [k, v]
                    end
                end
                flat
            end

            def merge_if(condition, h)
                if condition
                    merge(h)
                else
                    self
                end
            end
            alias_method :update_if, :merge_if
        end

        module MutatingMethods
            # Return the value for the given key. If the key has no value,
            # set it to initial and return that. If a block is given instead
            # of initial, call it and use the returned value.
            def cache(key, initial = nil)
                if key?(key)
                    self[key]
                else
                    self[key] = initial || yield
                end
            end

            # Same as #delete but default can be literal
            def delete_or(key, default = nil, &block)
                if key?(key) || default.nil?
                    delete(key, &block)
                else
                    default
                end
            end
        end
    end
end

class Hash
    include Ext::Hash::InstanceMethods
    include Ext::Hash::MutatingMethods
    extend Ext::Hash::ClassMethods
end
