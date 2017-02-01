module Buildable
    class Export < Transfer
        def get_attr(doc, attr)
            attr = attr.to_s
            if opts = model.buildable_attributes[attr]
                if to_unbuild = opts[:unbuild]
                    instance_exec(&to_unbuild)
                else
                    value = doc.__send__(attr)
                    field = model.fields[attr] and value == field.default_val and raise SkipAttribute

                    if value.is_a?(BSON::ObjectId)
                        value.to_s
                    else
                        value.as_json
                    end
                end
            end
        end

        def get_attrs(doc)
            attrs = {}
            model.buildable_attributes.keys.each do |attr|
                begin
                    attrs[attr] = get_attr(doc, attr)
                rescue SkipAttribute
                    # skip
                end
            end
            attrs
        end

        def get_yaml(doc)
            get_attrs(doc).to_yaml.sub(/\A---\n/, '')
        end

        def save(doc)
            path = path_from_doc(doc)
            yaml = get_yaml(doc)

            if File.exists?(path)
                logger.info "  update #{path}"
            else
                logger.info "  create #{path}"
            end

            store.write(path, yaml) unless dry?
        end

        def save_all
            logger.info "Saving model #{model} to #{model_dir}#{" (dry run)" if dry?}"

            paths = []
            model_scope.each do |doc|
                path = path_from_doc(doc)
                paths << path
                save(doc)
            end

            paths.each do |path|
                unless paths.include?(path)
                    logger.info "  delete #{path}"
                    store.delete(path) unless dry?
                end
            end
        end
    end
end
