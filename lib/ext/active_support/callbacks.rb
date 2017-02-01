module Ext
    module ActiveSupport
        module Callbacks
            extend ::ActiveSupport::Concern

            module ClassMethods
                def before_event(event, **opts, &block)
                    set_callback(event, :before, **opts, &block)
                end

                def around_event(event, **opts, &block)
                    set_callback(event, :around, **opts, &block)
                end

                def after_event(event, **opts, &block)
                    set_callback(event, :after, **opts,  &block)
                end

                def define_callback_macros(event)
                    [:before, :around, :after].each do |type|
                        define_singleton_method "#{type}_#{event}" do |*args, &block|
                            set_callback(event, type, *args, &block)
                        end
                    end
                end
            end

            module ClassPatches
                def set_callback_with_inline_check(event, *args, &block)
                    type, * = args
                    if type == :around && block && block.arity < 2
                        # This is the right way to define an inline around callback:
                        #
                        #     around_save do |obj, block|
                        #         ...
                        #         block.call
                        #         ...
                        #     end
                        #
                        # Note that the block is a normal second parameter, and NOT a block parameter.
                        # That's because it's impossible to forward a block parameter through #instance_exec,
                        # which ActiveSupport uses to invoke your callback, so it passes the block as a
                        # normal parameter instead.
                        #
                        # However, if your block doesn't take a second parameter, ActiveSupport will
                        # call it anyway, silently dropping the inner block and preventing the entire
                        # event from happening. This is, of course, absolutely useless, so I've added this
                        # check to save you the hours of hair pulling I went through figuring all this out.

                        raise ArgumentError, "Inline around callback must accept a block as second parameter (but NOT as a block parameter)"
                    else
                        set_callback_without_inline_check(event, *args, &block)
                    end
                end
            end
        end
    end
end

module ActiveSupport
    module Callbacks
        include ::Ext::ActiveSupport::Callbacks

        module ClassMethods
            include ::Ext::ActiveSupport::Callbacks::ClassPatches
            alias_method_chain :set_callback, :inline_check
        end
    end
end
