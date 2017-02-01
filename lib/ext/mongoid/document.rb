require 'ocn/mass_assignment_security'

module Mongoid
    module Document
        include OCN::MassAssignmentSecurity::DocumentExtensions

        # Including this module in a Mongoid::Document disables Mongoid's
        # built-in polymorphism mechanism that uses the :_type field.
        # Any subclasses of the model will be saved without this field,
        # and will be loaded back from the database as instances of the
        # base class, even if the _type field is present in the database.
        #
        # This is useful if you want to implement your own polymorphism
        # mechanism and you don't want Mongoid to interfere.
        module DisablePolymorphism
            extend ActiveSupport::Concern

            included do
                field :_type, overwrite: true
            end

            module ClassMethods
                def inherited(sub)
                    super
                    sub.field :_type, overwrite: true
                end

                def hereditary?
                    false
                end
            end

            module FactoryOverrides
                def build(klass, attributes = nil)
                    attributes.delete('_type') if klass.include? DisablePolymorphism

                    # This works around an apparent Mongoid bug where it tries to
                    # mass-assign these attributes even if they are not accessible.
                    _parent = attributes.delete(:_parent)
                    __metadata = attributes.delete(:__metadata)

                    obj = super

                    obj._parent = _parent if _parent
                    obj.__metadata = __metadata if __metadata

                    obj
                end

                def from_db(klass, attributes = nil, criteria_instance_id = nil)
                    attributes.delete('_type') if klass.include? DisablePolymorphism
                    super
                end
            end

            Mongoid::Factory.extend FactoryOverrides
        end

        # Validate the document and raise if it fails
        def validate!
            valid? or raise Mongoid::Errors::Validations.new(self)
        end

        # Call #save! on any referenced documents with changes,
        # recursively unless specified otherwise.
        #
        # The #update_attributes method will apply changes to
        # related documents, if attributes for them are nested
        # in the update, but will not save those documents.
        # Calling this method immediately afterward solves
        # that problem.
        def save_relations!(recurse: true)
            relations.each do |_, meta|
                unless meta.embedded?
                    values = send(meta.as || meta.name)
                    values = [values] unless meta.many?
                    values.each do |value|
                        if value && value.changed?
                            value.save!
                            value.save_relations! if recurse
                        end
                    end
                end
            end
        end

        # Undo application of default values
        def revert_default_application
            self.changes.each do |k, v|
                if v[0].nil? && self.fields[k].default_val == v[1]
                    self[k] = v[0]
                end
            end
        end

        def upsert_attributes(attrs)
            assign_attributes(attrs)
            upsert
        end

        def upsert_attributes!(attrs)
            result = upsert_attributes(attrs)
            unless result
                fail_due_to_validation! unless errors.empty?
                fail_due_to_callback!(:upsert_attributes!)
            end
            result
        end

        # Return a Criteria that matches self by its _id
        def where_self
            self.class.unscoped.where(id: self.id)
        end

        def others
            self.class.ne(id: self.id)
        end

        def changes_before
            changes.mash{|k, (v, _)| [k, v] }
        end

        def changes_after
            changes.mash{|k, (_, v)| [k, v] }
        end

        def imap
            self.class.imap
        end

        def store_in_imap(attr = '_id')
            imap[{attr.to_s => __send__(attr)}] = self
        end

        def remove_from_imap
            imap.delete_if do |_, v|
                v == self || (v.respond_to?(:include) && v.include?(self))
            end
        end

        def recursive_errors
            if block_given?
                errors.each do |key, message|
                    if message == 'is invalid' && doc = try(key)
                        doc.recursive_errors.each do |subkey, message|
                            yield "#{key}.#{subkey}", message
                        end
                    else
                        yield key, message
                    end
                end
            else
                enum_for :recursive_errors
            end
        end

        module ClassMethods
            # Verify that all keys of the raw selector map to fields or
            # relations of the model, and translate aliases to the names
            # used in the database.
            #
            # If a relation key has an instance of the related model as
            # its value, then the model instance will be replaced with
            # its primary_key, as specified in the relation. This works
            # even if the primary_key is not _id, which is a detail that
            # Mongoid's built-in query processing gets wrong.
            def cooked_selector(raw)
                cooked = {}
                raw.each do |name, value|
                    name = name.to_s
                    if meta = relations[name]
                        cooked[meta.foreign_key] = if value.respond_to?(:attributes)
                            value.attributes[meta.primary_key]
                        else
                            value
                        end
                    elsif meta = field_by_name(name)
                        cooked[meta.name] = value
                    else
                        raise TypeError, "#{self} has no field or relation named '#{name}'"
                    end
                end
                cooked
            end

            def field_scope(*names)
                names.each do |name|
                    scope name, -> (value) { where!(name => value) }
                end
            end

            def predicate_scope(name)
                scope name, -> (yes) { if yes then where!(name => true) else ne!(name => true) end }
            end

            # Before validation, set the given field to nil if its value matches the given predicate
            def nil_if(*fields, &test)
                assert_field_or_relation(*fields)
                before_validation do
                    fields.each do |field|
                        if test[read_attribute(field)]
                            write_attribute(field, nil)
                        end
                    end
                end
            end

            # Eagerly apply a default value to any field or relation that is nil after initialization
            def default_if(*fields, &test)
                assert_field_or_relation(*fields)
                after_initialize do
                    fields.each do |field|
                        if test[read_attribute(field)]
                            write_attribute(field, self.class.metadata(field).eval_default(self))
                        end
                    end
                end
            end

            # Ensure that the given field is not saved if its value matches the given predicate.
            # This is done by removing the attribute immediately prior to saving, and restoring
            # its previous value afterward.
            def unset_if(*fields, &test)
                assert_field_or_relation(*fields)
                around_save do |_, save_block|
                    values = {}
                    fields.each do |field|
                        value = read_attribute(field)
                        if test[value]
                            values[field] = value
                            remove_attribute(field)
                        end
                    end

                    save_block.call

                    values.each do |field, value|
                        write_attribute(field, value)
                    end
                end
            end

            def blank_to_nil(*fields)
                nil_if(*fields, &:blank?)
            end

            def default_if_nil(*fields)
                default_if(*fields, &:nil?)
            end

            def default_if_blank(*fields)
                default_if(*fields, &:blank?)
            end

            def unset_if_nil(*fields)
                unset_if(*fields, &:nil?)
            end

            def unset_if_blank(*fields)
                unset_if(*fields, &:blank?)
            end

            def process_field_validations(name, opts)
                # General inline validations
                validates = opts.delete_or(:validates, {})

                # Inline presence validations
                allow_nil = opts.delete(:allow_nil)
                if allow_nil == false
                    validates[:not_nil] = true
                end

                # Inline reference validations
                if reference = opts.delete(:reference)
                    validates[:reference] = reference
                end

                # Validate enums
                type = opts[:type]
                if type.is_a?(Module) && type.ancestors.include?(Enum)
                    validates[:inclusion] = {in: type.values}
                end

                unless validates.empty?
                    validates[:allow_nil] = allow_nil unless allow_nil.nil?
                    validates(name, **validates)
                end
            end

            def process_relation_options(type, name, opts)
                # Mongoid defaults this to true for all the has_* relations, which causes documents to be
                # validated at surprising times. It makes sense for embedded relations though.
                opts[:validate] = false if opts[:validate].nil? && type.to_s !~ /\Aembeds/

                if [:belongs_to, :has_one, :embeds_one].include?(type) && opts.key?(:default)
                    default_val = opts.delete(:default)
                    default_val = -> { default_val } unless default_val.respond_to? :call
                end

                process_field_validations(name, opts)

                yield

                if default_val
                    metadata(name).default_val = default_val
                    default_if_nil name # unlike fields, relation defaults are always eager
                end
            end

            # Override to support allow_nil and allow_blank options, and add automatic Enum validation
            def field(name, **opts)
                process_field_validations(name, opts)
                super(name, **opts)
            end

            [:has_one, :has_many, :has_and_belongs_to_many, :embeds_one, :embeds_many].each do |type|
                define_method type do |name, **opts|
                    process_relation_options(type, name, opts) do
                        super(name, **opts)
                    end
                end
            end

            def belongs_to(name, **opts)
                name = name.to_s
                process_relation_options(:belongs_to, name, opts) do
                    super(name, **opts)
                end

                meta = relations[name]
                name_without_imap = "#{name}_without_imap"
                define_method "#{name}_with_imap" do
                    (!meta.polymorphic? && meta.klass.imap_where(meta.primary_key => read_attribute(meta.foreign_key))) || __send__(name_without_imap)
                end
                alias_method_chain name, :imap
            end

            def scope(name, crit)
                if crit.is_a? Proc
                    super(name, crit)
                else
                    super(name, -> { crit })
                end
            end

            # Provides access to Mongoid's identity map cache. The hash
            # returned from this method should generally contain every
            # instance of the model loaded during the current unit of
            # work, keyed by _id.
            def imap
                Cache::RequestManager.get(self){ {} }
            end

            def imap_all
                imap[{}]
            end

            def imap_where(sel = {})
                imap[sel.stringify_keys]
            end

            def imap_find(*ids)
                if ids.size == 1
                    imap['_id' => ids[0]]
                elsif ids.size > 1
                    ids.map do |id|
                        imap['_id' => id]
                    end.compact
                end
            end
        end
    end
end
