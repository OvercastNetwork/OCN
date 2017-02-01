module Permissions
    # A model that contains an explicit permission tree persisted in a field
    module DirectHolder
        extend ActiveSupport::Concern
        include Mongoid::Document
        include Holder

        included do
            field :web_permissions, type: Hash, default: {}.freeze
            alias_method :permissions, :web_permissions
            alias_method :permissions=, :web_permissions=

            attr_accessible :web_permissions # TODO: should not be accessible

            validates_each :web_permissions do |record, attr, value|
                value.explode.each do |perm|
                    unless permission_schema.permission_exists?(*perm)
                        record.errors.add attr, "contains unknown permission #{perm.join('.')}"
                    end
                end
            end
        end

        module ClassMethods
            def with_permission(*permission)
                permission = permission_schema.expand(*permission)
                [*admins, *if docs = imap_all
                    docs.select{|doc| doc.has_permission?(permission) }
                else
                    *key, value = permission
                    where([:web_permissions, *key].join('.') => value)
                end]
            end
        end
    end
end
