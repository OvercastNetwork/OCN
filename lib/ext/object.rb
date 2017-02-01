module Ext
    module Object
        # If condition is true, return the result of passing self to the block.
        # If condition is false, return self.
        # The block is passed (self, condition) if it accepts the parameters.
        #
        # Allows this common pattern:
        #
        #     thing = calculate_thing
        #     thing = thing.transform if condition
        #     thing
        #
        # to be expressed more concisely, and without a temporary variable:
        #
        #     calculate_thing.transform_if(condition) {|thing| thing.transform }
        #
        # or just:
        #
        #     calculate_thing.transform_if(condition, &:transform)
        #
        # Often, the transform is predicated on the existence of some parameter:
        #
        #     thing = calculate_thing
        #     if parameter = calculate_transform_parameter
        #         thing = thing.transform(parameter)
        #     end
        #     thing
        #
        # This also becomes a single expression, avoiding both temporary variables:
        #
        #     calculate_thing.transform_if(calculate_transform_parameter) do |thing, parameter|
        #         thing.transform(parameter)
        #     end

        def transform_if(condition, &block)
            if condition
                case block.arity
                    when 0
                        yield
                    when 1
                        yield self
                    else
                        yield self, condition
                end
            else
                self
            end
        end

        def transform(&block)
            block.call(self)
        end

        def to_bool
            true
        end
    end
end

::Object.__send__(:include, ::Ext::Object)
