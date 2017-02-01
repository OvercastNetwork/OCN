module Mongoid
    module Indexable
        module ClassMethods
            # Define an index and verify the field names
            # See Mongoig::Document#cooked_selector
            def index!(spec, **options)
                index(cooked_selector(spec), *options)
            end

            # Same as #index but returns the spec for convenient assignment to a constant
            def index_spec(spec, **options)
                index(spec, **options)
                spec
            end

            def index_asc(*fields)
                fields.each do |field|
                    index(field => 1)
                end
            end

            def index_desc(*fields)
                fields.each do |field|
                    index(field => 1)
                end
            end
        end

        module BackgroundIndexes
            extend ActiveSupport::Concern

            module ClassMethods
                # Build indexes in the background by default
                def index(spec, options = nil)
                    super(spec, {background: true}.merge(options || {}))
                end
            end
        end
    end
end
