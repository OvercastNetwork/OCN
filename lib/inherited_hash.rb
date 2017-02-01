# A Hash-like object that inherits entries from any number of other Hashes.
# This is very handy e.g. for representing inheritable metadata.
#
#     # Entries are inherited from parents passed to #new
#     parent = {a: 1}
#     child = InheritedHash.new(parent)
#     child[:b] = 2
#     child
#         => {:b=>2, :a=>1}
#
#     # Parent modifications are visible from the child
#     parent[:a] = 3
#     child
#         => {:b=>2, :a=>3}
#
#     # Child entries override the parent without modifying the parent
#     child[:a] = 1
#     child
#         => {:a=>1, :b=>2}
#
#     # Can inherit from multiple parents, each parent can override its successors
#     uncle = {b: 4}
#     grandchild = InheritedHash.new(uncle, child)
#     grandchild
#         => {:b=>4, :a=>1}
#
# The #local method provides access to the local (non-inherited) entries.
#
# The #to_hash method flattens the hiearchy to an actual Hash, which *should*
# allow this class to be used as a substitute for Hash just about anywhere.
#
# A few mutating methods of Hash are not supported, because they don't really
# make sense in this context, namely:
#
#   rehash select! reject! shift delete delete_if keep_if clear
#   merge! update replace compare_by_identity compare_by_identity?
#
class InheritedHash
    include Enumerable
    include Ext::Hash::InstanceMethods

    attr :local, :parents

    def initialize(*parents, &default_proc)
        @local = {}
        @parents = parents.map(&:to_hash).freeze
        @default_proc = default_proc
    end

    # Inspection

    def inspect
        to_h.inspect
    end
    alias_method :to_s, :inspect

    def pretty_print(pp)
        to_h.pretty_print(pp)
    end

    # Comparison

    def hash
        to_h.hash
    end

    def ==(other_hash)
        to_h == other_hash
    end

    def eql?(other)
        to_h.eql?(other)
    end

    # Size

    def size
        parents.reduce(local.size){|sum, parent| sum + parent.size }
    end
    alias_method :length, :size

    def empty?
        local.empty? && parents.all?{|p| p.empty? }
    end

    # Existence predicates

    def key?(key)
        local.key?(key) || parents.any?{|parent| parent.key?(key) }
    end
    alias_method :has_key?, :key?
    alias_method :include?, :key?
    alias_method :member?, :key?

    def value?(value)
        # Be careful not to find a parent value that is overridden
        local.value?(value) || values.include?(value)
    end
    alias_method :has_value?, :value?

    # Defaults

    attr_writer :default
    attr_accessor :default_proc

    def default(key)
        if proc = default_proc
            proc.call(self, key)
        else
            @default
        end
    end

    # Getters

    def [](key)
        if local.key?(key)
            local[key]
        elsif parent = parents.find{|p| p.key?(key) }
            parent[key]
        else
            default(key)
        end
    end

    def fetch(key, *default, &block)
        if key?(key)
            self[key]
        elsif !default.empty?
            default[0]
        elsif block
            if block.arity == 0
                block.call
            else
                block.call(key)
            end
        else
            raise KeyError, "key not found: #{key.inspect}"
        end
    end

    def key(value)
        # Be careful not to return a parent key that is overridden
        if local.value?(value)
            local.key(value)
        else
            to_h.key(value)
        end
    end

    def values_at(*keys)
        keys.map{|key| self[key] }
    end

    # Setters

    def []=(k, v)
        local[k] = v
    end
    alias_method :store, :[]=

    # Iteration

    def each_key(&block)
        keys.each(&block)
    end

    def each_value(&block)
        values.each(&block)
    end

    def each
        if block_given?
            each_key do |key|
                yield key, self[key]
            end
        else
            enum_for :each
        end
    end
    alias_method :each_pair, :each

    # Transformation

    def keys
        Set[*local.keys, *parents.flat_map(&:keys)].to_a
    end

    def values
        values_at(*keys)
    end

    def to_h
        parents.reduce(local){|h, parent| parent.merge(h) }
    end
    alias_method :to_hash, :to_h

    def to_a
        each.to_a
    end

    def merge(h)
        to_h.merge(h)
    end

    def invert
        to_h.invert
    end

    # Filtration

    def select
        if block_given?
            h = {}
            each_pair do |k, v|
                h[k] = v if yield k, v
            end
            h
        else
            enum_for :select
        end
    end

    def reject
        if block_given?
            h = {}
            each_pair do |k, v|
                h[k] = v unless yield k, v
            end
            h
        else
            enum_for :reject
        end
    end

    # Stupid lisp shit I can't be bothered with

    def assoc(obj)
        to_h.assoc(obj)
    end

    def rassoc(obj)
        to_h.rassoc(obj)
    end

    def flatten(*args)
        to_h.flatten(*args)
    end
end
