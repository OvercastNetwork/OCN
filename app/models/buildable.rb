require_dependencies 'buildable/*'

module Buildable
    extend ActiveSupport::Concern
    include InheritedAttributes
    include Killable

    class BuildError < Exception; end
    class SkipAttribute < Exception; end

    included do
        mattr_inherited_hash :buildable_attributes
        delegate :buildable_attributes, to: self

        mattr_inherited_list :collection_validators
    end # included do

    module ClassMethods
        def attr_buildable(*attrs)
            assert_field_or_relation(*attrs)

            attrs.each do |attr|
                attr == '_id' and raise TypeError, "Do not explicitly declare _id as buildable"
                buildable_attributes[attr.to_s] = {}
            end
        end

        def builder_scope(s = nil)
            @builder_scope = s unless s.nil?

            if @builder_scope
                @builder_scope.call
            else
                all
            end
        end

        def to_unbuild(attr, &block)
            attr = attr.to_s
            opts = (buildable_attributes[attr] ||= {})
            opts[:unbuild] = block
        end

        def to_rebuild(attr, &block)
            attr = attr.to_s
            opts = (buildable_attributes[attr] ||= {})
            opts[:rebuild] = block
        end

        def validates_collection_with(&block)
            collection_validators << block
        end

        def validate_collection(loader)
            collection_validators.each do |v|
                v.call(loader)
            end
        end

        def create_saver(**opts)
            Export.new(model: self, **opts)
        end

        def create_loader(**opts)
            Import.new(model: self, **opts)
        end
    end # ClassMethods

    class << self
        def buildable_models
            Rails.application.eager_load! # Force all models to load
            Buildable.descendants.select do |model|
                model.is_a?(Class) && model < Mongoid::Document
            end
        end

        def create_savers(models: nil, store:, **opts)
            (models || buildable_models).map do |model|
                model.create_saver(store: store, **opts)
            end
        end

        def create_loaders(models: nil, store:, **opts)
            (models || buildable_models).map do |model|
                model.create_loader(store: store, **opts)
            end
        end

        def save_models(models: nil, store:, dry:)
            Buildable.create_savers(models: models, store: store, dry: dry).each do |saver|
                saver.save_all
            end
        end

        def load_models(models: nil, store:, dry:)
            loaders = Buildable.create_loaders(models: models, store: store, dry: dry)

            loaders.each do |loader|
                loader.load
                loader.log_changes
            end

            if loaders.all?(&:valid?)
                loaders.each(&:commit!)
                true
            else
                loaders.each(&:log_errors)
                false
            end
        end
    end
end
