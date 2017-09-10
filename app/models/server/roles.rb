class Server
    class Role < Enum
        create :PGM, :LOBBY, :BUNGEE, :MAPDEV
    end

    module Roles
        extend ActiveSupport::Concern

        included do
            field :role, type: Role, default: Role::PGM
            scope :role, -> (role) { where(role: role)}
            scope :not_role, -> (role) { ne(role: role) }

            scope :bukkits, not_role(Role::BUNGEE)
            scope :bungees, role(Role::BUNGEE)
            scope :lobbies, role(Role::LOBBY)
            scope :pgms, role(Role::PGM)

            attr_cloneable :role

            api_property :role
        end # included do

        def pgm?
            role == Server::Role::PGM
        end

        def lobby?
            role == Server::Role::LOBBY
        end

        def bungee?
            role == Server::Role::BUNGEE
        end

        def bukkit?
            !bungee?
        end
    end # Roles
end
