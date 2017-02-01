module Component
    class Builder
        def initialize(&block)
            @extra = []
            instance_exec(&block)
        end

        def to_components
            @extra
        end

        def to_component
            if @extra.size == 1
                @extra[0]
            else
                Text.new(extra: @extra)
            end
        end

        def text(text = '', **args, &block)
            @extra << Text.new(text, extra: sublist(&block), **args)
        end

        # Note: block contains components for 'with', not 'extra'
        def translate(translate, **args, &block)
            @extra << Translate.new(translate, with: sublist(&block), **args)
        end

        # ClickEvent is returned and not stored anywhere
        def click_event(action, value)
            ClickEvent.new(action: action, value: value)
        end

        # HoverEvent is returned and not stored anywhere
        def hover_event(action, value = nil, &block)
            HoverEvent.new(action: action, value: if value
                [*value]
            else
                Builder.new(&block).to_components
            end)
        end

        private

        def sublist(&block)
            if block
                Builder.new(&block).to_components
            else
                []
            end
        end
    end
end
