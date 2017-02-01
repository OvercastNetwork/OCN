module Permissions
    extend ActiveSupport::Concern

    class Denied < Exception; end

    class << self
        attr :schema

        delegate :permissions, :everybody_permission,
                 :expand_without_assert, :expand, :permission_exists?, :assert_permission_exists,
                 :each_permission, :pretty_permissions,
                 to: :schema
    end

    @schema = Definitions::ROOT.schema
end
