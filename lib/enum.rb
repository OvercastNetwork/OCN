# Example usage:
#
#   class Mood < Enum
#       create :HAPPY, :SAD
#   end
#
# Each argument creates an instance of Mood, which can be
# accessed as a nested constant, or through the #[] method:
#
#   > Mood[:HAPPY]
#     => Mood::HAPPY
#
#   > Mood::HAPPY
#     => Mood::HAPPY
#
# Calling #[] with an undefined name will raise a NameError
#
# Various serialization methods are supported:
#
#   > Mood::HAPPY.serialize
#   > Mood::HAPPY.as_json
#   > Mood::HAPPY.mongoize
#   > Mood::HAPPY.to_s
#     => "HAPPY"
#
#   > Mood.deserialize("HAPPY")
#   > Mood.demongoize("HAPPY")
#     => Mood::HAPPY
#
# Each instance has both a name and a serialized name. If the instance
# was created from a positional argument to #create, then these will
# be identical, whereas keyword arguments allow them to be specified
# seperately:
#
#   class Mood < Enum
#       create :HAPPY, SAD: "UNHAPPY"
#   end
#
# Enums are always serialized as a plain string equal to the serialized name,
# which often allows them to serve as drop-in replacements for ad-hoc choice fields.
#
# The case of serialized names is preserved, but deserialization is case-insensitive,
# and multiple names that differ only by case are not allowed.
#
# Enums can be enumerated in various ways:
#
#   > Mood.names
#     => [:HAPPY, :SAD]
#
#   > Mood.values
#     => [Mood:HAPPY, Mood:SAD]
#
#   > Mood.by_name
#     => {:HAPPY=>Mood:HAPPY, :SAD=>Mood:SAD}
#
#   > Mood.by_serialized_name
#     => {"HAPPY"=>Mood:HAPPY, "unhappy"=>Mood:SAD}
#
class Enum
    include Comparable

    class Error < NameError
        attr_reader :enum
        def initialize(msg, enum, name)
            super(msg, name)
            @enum = enum
        end
    end

    attr_reader :name
    alias_method :to_sym, :name

    attr_reader :serialize
    alias_method :to_s, :serialize
    alias_method :mongoize, :serialize

    def as_json(*)
        serialize
    end

    def initialize(name, serialize = nil)
        @name = name.to_s.to_sym
        @serialize = (serialize || @name).to_s

        self.class.by_name.key?(@name) and raise Error.new("Duplicate #{self.class.name} name '#{@name}'", self, @name)
        self.class.by_serialized_name.key?(@serialize.upcase) and raise Error.new("Duplicate #{self.class.name} serializaed name '#{@serialize}'", self, @serialize)

        self.class.by_name[@name] = self
        self.class.by_serialized_name[@serialize.upcase] = self
        self.class.const_set(@name, self)
    end

    def inspect
        "#{self.class.inspect}::#{name}"
    end

    def <=>(other)
        self.class.values.index(self) <=> self.class.values.index(other)
    end

    class << self
        def create(*regular, **irregular)
            regular.each{|name| new(name) }
            irregular.each{|name, value| new(name, value) }
        end

        def by_name
            @by_name ||= {}
        end

        def names
            by_name.keys
        end

        def values
            by_name.values
        end

        def [](name)
            by_name[name.to_sym] or raise Error.new("No #{self.name} named #{name}", self, name)
        end

        def by_serialized_name
            @by_serialized_name ||= {}
        end

        def serialized_names
            by_serialized_name.keys
        end
        
        def deserialize(str)
            unless str.nil?
                str = str.to_s.upcase
                by_serialized_name[str] or raise Error.new("No #{name} with serialized name #{str}", self, str)
            end
        end
        alias_method :demongoize, :deserialize

        def serialize(obj)
            case obj
                when Enum then obj.serialize
                else obj
            end
        end
        alias_method :mongoize, :serialize
        alias_method :evolve, :serialize
    end
end
