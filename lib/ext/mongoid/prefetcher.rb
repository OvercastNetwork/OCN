module Mongoid
    class Prefetcher
        class ModelCache
            attr_reader :docs_by_key, :keys

            def initialize(model, field = :_id)
                @model = model
                @field = field
                @keys = Set[]
                @docs_by_key = {}
            end

            def fetch_docs
                unless @keys.empty?
                    @docs_by_key.merge!(@model.in(@field => @keys.to_a).index_by{|doc| doc.send(@field) })
                    @keys.clear
                end
            end
        end

        attr_reader :docs, :paths, :model, :caches

        def initialize(docs)
            @docs = docs
            @model = docs.klass
            @paths = []
            @caches = {}
        end

        def add_field(name)
            model = @model
            path = name.to_s.split('.').map do |field|
                unless relation = model.relations[field.to_s]
                    raise TypeError, "Model #{model} has no relation named #{field}"
                end
                model = relation.klass
                relation
            end
            @paths << path unless path.empty?
        end

        def model_cache(relation)
            key = [relation.klass, relation.primary_key]
            @caches[key] ||= ModelCache.new(*key)
        end

        def fetch_docs
            @caches.values.each(&:fetch_docs)
        end

        def get_foreign_key(doc, path)
            path[0..-2].each do |rel|
                return unless doc = doc.send(rel.name)
            end
            [doc, doc[path[-1].key]]
        end

        def each_path(level)
            @docs.each do |doc|
                @paths.select{|path| path.size > level }.each do |path|
                    sub, key = get_foreign_key(doc, path[0..level])
                    yield sub, path[level], key if sub
                end
            end
        end

        def gather_keys(level)
            each_path(level) do |_, rel, key|
                model_cache(rel).keys << key
            end
        end

        def set_relations(level)
            each_path(level) do |doc, rel, key|
                doc.set_relation(rel.name, model_cache(rel).docs_by_key[key])
            end
        end

        def fetch
            @paths.map(&:size).max.times do |level|
                gather_keys(level)
                fetch_docs
                set_relations(level)
            end
        end
    end
end
