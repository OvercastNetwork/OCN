module Permissions
    # Abstract base for any object that holds permissions, either directly or indirectly
    module Holder
        extend ActiveSupport::Concern
        
        module ClassMethods
            def permission_schema
                Permissions.schema
            end

            # Return all Holders that hold the given permission.
            # Subclasses should reimplement this.
            def with_permission(*permission)
                instances.select do |holder|
                    holder.has_permission?(permission)
                end
            end

            # Return all Holders that implicitly hold all permissions.
            # Base returns empty, subclasses can override.
            def admins
                instances.select(&:admin?)
            end
        end # ClassMethods

        delegate :permission_schema, to: :class
        
        # Return the tree of permissions held by this holder.
        # Subclasses must implement this.
        def permissions
            raise NotImplementedError
        end

        # Does this holder implicitly hold all permissions?
        # Base returns false, subclasses can override.
        def admin?
            false
        end

        # Return the web_permissions subtree for the given permission prefix.
        # If there is no subtree at the given prefix, nil is returned.
        # Per-instance permissions are not generalized to the parent node.
        def permission_subtree_raw(*nodes)
            nodes.reduce(permissions) do |tree, node|
                if tree.is_a? Hash
                    tree[node.to_s] || tree[node.to_sym]
                end
            end
        end
        
        # Return the web_permissions subtree for the given permission prefix.
        # If the prefix is instance-specific, and there is no subtree at the prefix,
        # the generic parent prefix is returned instead.
        def permission_subtree(*nodes)
            perms = permission_subtree_raw(*nodes)

            if perms.nil? && permission_schema.generic_permission?(*nodes)
                domain, _, *suffix = nodes
                perms = permission_subtree_raw(domain, 'parent', *suffix)
            end

            perms
        end

        # Does this object hold the given complete permission?
        # Raises ArgumentError if the given permission does not exist.
        def has_permission?(*permission)
            permission = permission_schema.expand(*permission)
            permission == permission_schema.everybody_permission || admin? or begin
                *key, expected = permission
                expected = permission_schema.normalize_node(expected)
                actual = permission_schema.normalize_node(permission_subtree(*key))
                expected == actual || (expected == ['own'] && actual == ['all'])
            end
        end

        # Raise Permissions::Denied unless this object had the given complete permission
        def assert_permission(*args)
            unless has_permission?(*args)
                raise Permissions::Denied, "missing permission #{args.flatten.join('.')}"
            end
        end
    end # Holder
 end
