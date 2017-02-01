Rails.configuration.query_logging = false

$commit = ARGV.include?('--commit')

module Mongoid
    module Document
        module ClassMethods
            # Yield each document and print a progress message to
            # stdout every 1000 documents. If the block returns
            # a string, it will be appended to the progress message.
            def each_print_progress(label=self.name)
                total = self.count
                self.each_with_index do |doc, n|
                    msg = Cache::RequestManager.unit_of_work do
                        yield doc
                    end

                    if n.multiple_of?(1000)
                        puts "#{label} #{n}/#{total}#{": #{msg}" if msg}"
                    end
                end
            end

            def each_slice_print_progress(slice_size = 1000, label = self.name)
                total = self.count
                count = 0
                self.each_slice(slice_size) do |objs|
                    puts "#{label} (#{count + 1}..#{count + objs.size})/#{total}"
                    yield objs
                    count += objs.size
                end
            end
        end
    end
end

# Save safety/speed tradeoff
module Safety
    UNSAFE = 0          # Unacknowledged writes, very fast but errors are undetectable
    ACKNOWLEDGE = 1     # Skip validation and callbacks, verify DB writes
    CALLBACKS = 2       # Skip validation but run callbacks
    VALIDATE = 3        # Validate and run callbacks
end

class Slice
    attr_reader :docs, :missing

    def initialize(docs, missing: nil, safety: nil)
        @docs = docs
        @missing = missing || Hash.default { Set[] }
        @safety = safety || Safety::VALIDATE

        @prefetch_ids = Hash.default{ Set[] }
        @prefetch_docs = Hash.default{ {} }
    end

    def each
        @docs.each{|doc| yield doc }
    end

    def to_oid(id)
        if id.is_a? BSON::ObjectId
            id
        else
            BSON::ObjectId.from_string(id.to_s)
        end
    end

    def prefetch(model, id)
        @prefetch_ids[model] << to_oid(id) if id
    end

    def fetch(model, id)
        @prefetch_docs[model][to_oid(id)]
    end

    def do_prefetch
        @prefetch_ids.each do |model, ids|
            docs_by_id = model.in(id: ids.to_a ).index_by(&:id)
            @missing[model] += (ids - docs_by_id.keys)
            @prefetch_docs[model] = docs_by_id
        end
        @prefetch_ids.clear
    end

    class Skip < Exception; end

    def migrate_each(&block)
        do_prefetch

        @docs.each do |doc|
            begin
                instance_exec(doc, &block)
                save(doc)
            rescue Skip
                # ignore
            rescue
                puts "Error migrating document:\n#{doc.inspect}"
                raise
            end
        end
    end

    def skip
        raise Skip
    end

    def save(doc)
        if @safety >= Safety::CALLBACKS
            doc = doc.timeless if doc.respond_to? :timeless
            unless doc.save(validate: @safety >= Safety::VALIDATE)
                puts "Validation of #{doc.id} failed:\n"
                doc.errors.each do |field, problem|
                    puts "#{field}: #{problem}"
                end
            end
        else
            update = {}
            doc.changes.each do |field, change|
                _, after = change
                update[field] = after
            end

            unless update.empty?
                doc.mongo_client.with(safe: @safety >= Safety::ACKNOWLEDGE) do |session|
                    session[doc.collection.name].where(_id: doc.id).update($set => update)
                end
            end
        end
    end

    class << self
        def migrate(criteria, slice_size: 1000, safety: nil, &block)
            model = criteria.klass
            total = model.count
            migrated = total - criteria.count
            missing = Hash.default{ Set[] }

            criteria.each_slice(slice_size) do |docs|
                puts "#{model} #{migrated + 1}..#{migrated + docs.size} of #{total}"
                slice = Slice.new(docs, missing: missing, safety: safety)
                slice.instance_eval(&block)
                migrated += docs.size
            end

            puts "Missing documents:"
            missing.each do |model, ids|
                puts "#{model}: #{ids.to_a.join(' ')}"
            end
        end
    end
end

def mass_migrate(criteria, description)
    n = criteria.count
    if n > 0
        puts " #{n.to_s.rjust(9)} #{ "(dry run) " unless $commit}#{description}"
        yield criteria if $commit
    end
end

def mass_copy_field(criteria, from, to)
    values = criteria.distinct(from)
    puts "Copying #{values.size} distinct values of #{from} to #{to}"
    values.each do |value|
        criteria.where(from => value).set(to => value)
    end
end

def mass_validate(criteria, limit: 100)
    unless $commit
        puts "Skipping validation for dry run"
        return
    end

    ids = []
    total = criteria.count
    puts "Validating #{total} #{criteria.klass.model_name.plural}"

    criteria.each_with_index do |doc, i|
        if i % 1000 == 0
            puts "#{i}/#{total}"
        end

        begin
            unless doc.valid?
                puts "#{doc.id}:"
                puts doc.recursive_errors.map{|key, error| "    #{key} #{error}" }

                ids << doc.id
                if limit && ids.size >= limit
                    puts "Aborting validation due to limit #{limit}"
                    break
                end
            end
        rescue => ex
            puts "#{doc.id}: #{ex.format_long}"
        end
    end

    fn = 'invalid_ids'
    puts "Total #{ids.size} invalid documents:\n#{ids.map(&:to_s).join(' ')}"
end
