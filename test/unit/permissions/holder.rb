class Holder
    include Permissions::Holder

    attr_accessor :admin
    attr_accessor :permissions
    alias_method :admin?, :admin

    def initialize(admin: false, permissions: {})
        @admin = admin
        @permissions = permissions
    end

    class << self
        attr :permission_schema
    end
    @permission_schema = Permissions::Builders::Root.new do
        domain :global do
            node :everybody do
                option true
            end
        end

        domain :woot do
            boolean :donk
            ownable :zing
        end
    end.schema
end
