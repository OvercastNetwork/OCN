module Component
    class Text < Base
        attr_reader :text

        def initialize(text = '', **rest)
            super(**rest)
            @text = text.to_s.freeze
        end

        protected

        def full_json
            {'text' => text}.merge!(super)
        end
    end
end
