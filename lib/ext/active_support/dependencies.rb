module ActiveSupport
    module Dependencies
        module Loadable
            # Expand the given wildcard pattern against all autoload paths
            def glob_dependencies(pattern)
                if block_given?
                    Dependencies.autoload_paths.each do |root|
                        Dir.glob(File.join(root, pattern)) do |path|
                            yield path if path =~ %r[.rb\z]
                        end
                    end
                else
                    enum_for :glob_dependencies
                end
            end

            # Essentially the same as #require_dependency, but supports wildcard
            # patterns of the type that can be passed to Dir.glob. The pattern
            # will be applied to ALL autoload roots, and all matching .rb files
            # from each root will be autoloaded.
            def require_dependencies(pattern, allow_nothing: false)
                glob_dependencies(pattern) do |path|
                    allow_nothing = true
                    require_or_load(path)
                end
                allow_nothing or raise LoadError, "No dependencies matched the pattern '#{pattern}' (specify allow_nothing: true to allow this)"
            end
        end
    end
end
