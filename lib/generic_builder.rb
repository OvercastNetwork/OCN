
# Implements a generic DSL for defining sets of Hashs
#
# builder = GenericBuilder.new(:thing, :things) do
#    # Define a thing with id="woot" and foo="bar"
#    thing "woot", foo: "bar"
#
#    # Set foo="bar" for all following things in the current block
#    foo "bar"
#
#    # Set foo="bar" for all things in the given block
#    things foo: "bar" do
#        ...
#    end
#
#    # Same as above
#    foo "bar" do
#      ...
#    end
# end
#
# builder.instances.map{|props| Thing.new(**props) }

class GenericBuilder
    attr_reader :attributes, :instances

    def initialize(singular, plural, primary_field = :id, attrs = {}, &block)
        @singular = singular
        @plural = plural
        @primary_field = primary_field
        @attributes = attrs.dup
        @instances = []

        singleton_class.instance_eval do
            alias_method singular, :singular
            alias_method plural, :plural
        end

        instance_eval(&block) if block
    end

    def singular(primary = nil, attrs = {}, &block)
        attrs = @attributes.merge(attrs)
        attrs[@primary_field] = primary if primary
        @instances << self.class.new(@singular, @plural, @primary_field, attrs, &block).attributes
    end

    def plural(attrs = {}, &block)
        @instances += self.class.new(@singular, @plural, @primary_field, @attributes.merge(attrs), &block).instances if block
    end

    def method_missing(attr, *args, &block)
        if args.size == 1
            value = args[0]
            if block
                plural(attr => value, &block)
            else
                @attributes[attr] = value
            end
        else
            super
        end
    end
end

