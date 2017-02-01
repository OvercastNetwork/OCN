module Component
    class Translate < Base
        attr_reader :translate, :with

        def initialize(translate, with: [], **rest)
            super(**rest)
            @translate = translate.to_s.freeze
            @with = with.freeze
        end

        protected

        def full_json
            json = {'translate' => translate}
            json.merge!('with' => with.map(&:as_json)) unless with.empty?
            json.merge!(super)
        end
    end
end
