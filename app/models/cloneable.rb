
# Allows a model to specify explicitly which attributes are copied by the #clone method.
# This is useful for excluding unique fields, or for models that include a mixture of
# configuration and state data (though it would probably be better to split such models
# up eventually).

module Cloneable
    extend ActiveSupport::Concern
    include InheritedAttributes

    included do
        mattr_inherited_hash :cloneable_attributes
        delegate :cloneable_attributes, to: self
    end # included do

    module ClassMethods
        def attr_cloneable(*names)
            names.each do |name|
                cloneable_attributes[name.to_s] = {}
            end
        end
    end

    def clone
        self.class.without_attr_protection do
            self.class.new(cloneable_attributes.keys.mash{|key| [key, __send__(key)] })
        end
    end
end
