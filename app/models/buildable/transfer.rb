module Buildable
    # Code shared by Import and Export operations
    class Transfer
        include Loggable

        attr :model, :store, :by_id, :dry
        alias_method :dry?, :dry

        def initialize(model:, store:, dry: true)
            @model = model
            @store = store
            @dry = dry

            @by_id = {}
        end

        def model_scope
            model.builder_scope
        end

        def model_dir
            model.model_name.plural
        end

        def path_from_id(id)
            File.join(model_dir, "#{id}.yml")
        end

        def path_from_doc(doc)
            path_from_id(doc.id)
        end

        def paths
            store.glob(path_from_id('*'))
        end

        def id_from_path(path)
            fn = File.basename(path)
            if fn !~ /(.*)\.yml/
                raise BuildError, "Cannot parse ID from filename '#{fn}'"
            end
            id = $1
            if id.blank? || id != id.slugify(allow: '\-')
                raise BuildError, "Invalid ID format '#{id}'"
            end
            id
        end
    end
end
