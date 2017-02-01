module CouchHelper
    extend ActiveSupport::Concern

    META_PROPERTIES = %i[_id _rev]
    CONFLICT_RESOLUTION_TRIES = 5

    JSON_TIME_RE = /\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ/ # Strict time format, used to detect time values

    module Util
        def load_value(v)
            if v =~ JSON_TIME_RE
                Time.json_create(v).utc
            else
                v
            end
        end
    end

    include Util
    extend Util

    def save(db: nil, validate: true, conflict: nil, max_tries: CONFLICT_RESOLUTION_TRIES, &block)
        db ||= self.class.database
        tries = 0

        begin
            tries += 1
            result = db.save_document(self, validate, &block)
            if !result && validate == :raise
                raise(CouchPotato::Database::ValidationsFailedError.new(errors.full_messages))
            else
                result
            end
        rescue RestClient::Conflict
            if conflict && tries < max_tries
                case conflict
                    when :ours
                        self._rev = current_revision(db: db)
                        retry
                    else
                        raise ArgumentError, "Unknown conflict resolution strategy #{conflict.inspect}"
                end
            else
                raise CouchPotato::Conflict, "Failed to resolve conflict after #{tries} tries"
            end
        end
    end

    def save!(**opts, &block)
        self.save(validate: :raise, **opts, &block)
    end

    def current_revision(db: nil)
        db ||= self.class.database

        doc = db.load_document(self._id) and doc['_rev']
    end

    def destroy(db: nil)
        db ||= self.class.database

        if self._rev ||= current_revision(db: db)
            db.destroy_document(self)
        end
    end

    def normalize
        self[:_id] = self._id if self[:_id].blank?
    end

    def initialize(*args)
        super
        normalize
    end

    included do |mod|
        mod.before_validation :normalize
        mod.before_save :normalize
    end

    module ClassMethods
        include Util

        attr_accessor :database_name

        def database
            if database_name
                CouchPotato.use(database_name)
            else
                CouchPotato.database
            end
        end

        def load(id)
            database.load(id)
        end

        def make_view(view, **args)
            if view.is_a?(CouchPotato::View::BaseViewSpec)
                view.params(**args)
            else
                send(view, **args)
            end
        end

        def first_view_key(view, **args)
            view = make_view(view, **args)
            rows = query(view.params(reduce: false, limit: 1))['rows']
            load_value(rows[0]['key']) unless rows.empty?
        end

        def last_view_key(view, **args)
            view = make_view(view, **args)
            rows = query(view.params(reduce: false, descending: !view.descending, limit: 1))['rows']
            load_value(rows[0]['key']) unless rows.empty?
        end

        def query(view, **args)
            view = make_view(view, **args)
            if view.keys && view.keys.any?{|key| key.is_a? Range }
                keys = view.keys
                view = view.all_keys

                {'rows' => keys.flat_map do |key|
                    if key.is_a?(Range)
                        rows = query(view.params(startkey: key.begin, endkey: key.end))['rows']
                        rows.each{|row| row['key_range'] = key }
                        rows
                    else
                        query(view.params(key: key))['rows']
                    end
                end}
            else
                database.view(make_view(view, **args))
            end
        end

        def sliced_query(view, slices: 1, **args)
            view = make_view(view, **args)

            unless startkey = view.startkey
                rows = query(view.all_keys.params(reduce: false, descending: false, limit: 1))['rows']
                rows.empty? and return {'rows' => []}
                startkey = load_value(rows[0]['key'])
            end

            unless endkey = view.endkey
                rows = query(view.all_keys.params(reduce: false, descending: true, limit: 1))['rows']
                rows.empty? and return {'rows' => []}
                endkey = load_value(rows[0]['key'])
            end

            range = startkey..endkey
            view = view.reduce(true)

            if slices < 1
                raise ArgumentError, "Cannot slice a view into less than one piece"
            else
                query(view, keys: range.subdivide(slices))
            end
        end

        def derived_property(name, &block)
            define_method(name, &block)

            define_method "#{name}=" do |value|
                raise "Can't assign arbitrary #{name} to #{self.class} (#{value.inspect})" unless value == self.send(name)
            end

            if name.to_s == '_id'
                alias_method :id, :_id
                alias_method :id=, :_id=
            elsif name.to_s == 'id'
                alias_method :_id, :id
                alias_method :_id=, :id=
            end
        end
    end
end
