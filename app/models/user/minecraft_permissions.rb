class User
    module MinecraftPermissions
        extend ActiveSupport::Concern

        included do
            api_synthetic :mc_permissions_by_realm
        end

        def mc_permissions_by_realm
            permissions = Hash.default{ {} }
            [Group.default_group, *active_groups.reverse].each do |group|
                group.minecraft_permissions.each do |realm, perms|
                    permissions[realm].merge!(Group.decode_mc_permissions(perms))
                end
            end
            permissions
        end

        def has_mc_permission?(perm, realms = nil)
            admin? || self.mc_permissions(realms || ['global'])[perm]
        end

        def is_mc_staff?(realms = Server::PUBLIC_REALMS)
            self.has_mc_permission?('projectares.staff', realms) unless disguised_to?
        end

        # Returns a hash of {"node" => true|false}. A false node means
        # the perm should be removed from the player, even if they get
        # it from being op.
        def mc_permissions(realms)
            permissions = Group.default_group.merge_mc_permissions({}, realms)

            self.active_groups.reverse.each do |group|
                permissions = group.merge_mc_permissions(permissions, realms)
            end

            permissions
        end
    end
end
