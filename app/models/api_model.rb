# Module included in models that can be serialized through the API.
#
# This module adds the #api_document method, which returns the JSON
# representation of the a model instance. This document contains
# only the fields declared with the #api_property macro.
# If no properties are declared at all, the document will include
# all fields in the model.
#
# Another macro #api_synthetic can be used to add a generated property
# to the JSON document. The given block is called in the context of the
# instance being serialized, and should return the value for the property.
#
# Example:
#
#     class MyModel
#         include ApiModel
#
#         field :woot
#         field :donk
#
#         api_property :woot, :donk
#
#         api_synthetic :zing do
#             # ...
#         end
#     end
#
module ApiModel
    extend ActiveSupport::Concern
    include Mongoid::Document
    include InheritedAttributes
    include ApiSearchable

    # Latest API version
    LATEST_PROTOCOL_VERSION = 4
    CURRENT_PROTOCOL_VERSION = ThreadLocal.new(LATEST_PROTOCOL_VERSION)

    class << self
        def protocol_version
            CURRENT_PROTOCOL_VERSION.get
        end

        def with_protocol_version(version, &block)
            CURRENT_PROTOCOL_VERSION.with(version || LATEST_PROTOCOL_VERSION, &block)
        end

        def protocol_version?(version)
            protocol_version >= version
        end
    end

    delegate :protocol_version, :protocol_version?, :with_protocol_version, to: self

    class Property
        attr :model

        def initialize(model:)
            @model = model
        end

        def name
            raise NotImplementedError
        end

        def get(instance, opts)
            raise NotImplementedError
        end

        def apply(instance, document, opts)
            document[name] = get(instance, opts) if opts
        end

        def get_value(value, opts)
            if value.respond_to? :api_document
                # If opts is a Hash, it is the options for a related #api_document call
                opts = {} unless opts.respond_to? :to_hash
                value.api_document(**opts).as_json
            else
                value.as_json
            end
        end
    end

    class MetadataProperty < Property
        attr :meta
        delegate :name, to: :meta

        def initialize(model:, meta:)
            super(model: model)
            @meta = meta
        end
    end

    class FieldProperty < MetadataProperty
        def get(instance, opts)
            get_value(instance.__send__(meta.options[:as] || meta.name), opts)
        end
    end

    class RelationProperty < MetadataProperty
        def get(instance, opts)
            value = instance.__send__(meta.name)

            if meta.many?
                # Force empty embedded lists to be [] instead of nil
                (value || []).map{|v| get_value(v, opts) }
            else
                get_value(value, opts)
            end
        end
    end

    class SyntheticProperty < Property
        attr :name, :getter

        def initialize(model:, name:, getter:)
            super(model: model)
            @name = name
            @getter = if getter.is_a? Symbol
                model.instance_method(getter)
            else
                getter
            end
        end

        def get(instance, opts)
            value = if getter.is_a? UnboundMethod
                bound = getter.bind(instance)
                if bound.arity > 0
                    bound.call(opts)
                else
                    bound.call
                end
            else
                if getter.arity > 0
                    instance.instance_exec(opts, &getter)
                else
                    instance.instance_exec(&getter)
                end
            end
            get_value(value, opts)
        end
    end

    included do
        mattr_inherited_hash :api_properties do
            {'_id' => FieldProperty.new(model: self, meta: field_by_name('_id'))}
        end
    end

    module ClassMethods
        def api_property(*names)
            names.each do |name|
                name = name.to_s
                unless api_properties.key?(name)
                    api_properties[name] = if field = field_by_name(name)
                        FieldProperty.new(model: self, meta: field)
                    elsif relation = relations[name]
                        RelationProperty.new(model: self, meta: relation)
                    else
                        raise TypeError.new("Model #{self} has no field or relation named '#{name}'")
                    end
                end
            end
        end

        def api_synthetic(name, method = nil, &block)
            method && block and raise TypeError.new("Provide a method name or block, not both")
            name = name.to_s

            getter = if block
                block
            else
                instance_method(method || name)
            end

            api_properties[name] = SyntheticProperty.new(model: self, name: name, getter: getter)
        end

        def api_property?(name)
            api_properties.key?(name.to_s)
        end

        def assert_api_property(*names)
            names.each do |name|
                api_property?(name) or raise "Unknown API property '#{name}'"
            end
        end
    end

    def api_properties
        self.class.api_properties
    end

    def api_document(fields: {}, only: nil)
        fields = fields.stringify_keys
        self.class.assert_api_property(*fields.keys)

        if only
            only = only.map(&:to_s)
            self.class.assert_api_property(*only)
        end

        doc = {}
        api_properties.each do |name, property|
            if (fields[name] || fields[name].nil?) && (only.nil? || only.include?(name))
                doc[name] = property.get(self, fields[name] || {})
            end
        end
        doc
    end
end # Api
