module CouchPotato
    module View
        class BaseViewSpec
            def replace_range_key(params)
                if (key = params[:key]).is_a?(Range)
                    params.delete :key
                    params[:startkey] = key.first
                    params[:endkey] = key.last
                    params[:inclusive_end].nil? and params[:inclusive_end] = !key.exclude_end?
                end
                params
            end

            def replace_params(**p)
                if p.empty?
                    self
                else
                    self.class.new(
                        @klass,
                        @view_name,
                        @options,
                        p
                    )
                end
            end

            def params(**p)
                replace_params(view_parameters.merge(p))
            end

            def all_keys
                replace_params(view_parameters.without(*KEY_PARAM_NAMES))
            end

            KEY_PARAM_NAMES = %i[key keys startkey startkey_docid endkey endkey_docid]
            PARAM_NAMES = KEY_PARAM_NAMES + %i[limit stale descending skip group group_level reduce include_docs inclusive_end]
            NO_VALUE = Object.new

            PARAM_NAMES.each do |param|
                define_method(param) do |value = NO_VALUE|
                    if value == NO_VALUE
                        view_parameters[param]
                    else
                        params(param => value)
                    end
                end
            end
        end
    end
end
