require 'active_support/concern'

require_dependency 'generic_builder'

# Very simple non-persistent model, used for static data
module MiniModel
    extend ActiveSupport::Concern
    include ActiveModel::Model
    include ActiveSupport::Callbacks
    include Loggable

    attr_reader :id

    def initialize(id:, **values)
        @id = id

        values.each do |k, v|
            if self.class.fields[k]
                instance_variable_set(self.class.field_to_ivar(k), v)
            else
                raise ArgumentError, "Unknown field '#{k}'"
            end
        end

        cls = self.class
        while cls && cls < MiniModel
            cls.imap[id] = self
            cls = cls.superclass
        end

        after_create
    end

    def after_create
    end

    module ClassMethods
        include Enumerable

        def fields
            @fields ||= if superclass < MiniModel
                InheritedHash.new(superclass.fields)
            else
                {}
            end
        end

        def field_to_ivar(name)
            "@#{name.to_s.sub(/\?|!$/, '')}"
        end

        def field(name, **opts)
            fields[name] = opts
            ivar = field_to_ivar(name)
            define_method(name) { instance_variable_get(ivar) }
        end

        # All instances by id
        def imap
            @imap ||= HashWithIndifferentAccess.new
        end

        # All instances in order of creation
        def all
            imap.values # Yes, Ruby preserves insertion order of Hash
        end

        def [](id)
            imap[id.to_sym]
        end

        def find_or_create(id)
            self[id] || new(id: id)
        end

        def each
            if block_given?
                all.each{|obj| yield obj }
            else
                all.to_enum
            end
        end

        def builder(&block)
            name = self.name.underscore
            GenericBuilder.new(name.singularize, name.pluralize, &block)
        end

        def define(&block)
            builder(&block).instances.map do |props|
                klass = props.delete(:class) || props.delete(:klass) || self
                klass.new(**props)
            end
        end
    end
end
