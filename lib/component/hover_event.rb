module Component
    class HoverEvent
        class Action < Enum
            create :SHOW_TEXT, :SHOW_ACHIEVEMENT, :SHOW_ITEM
        end

        attr_reader :action, :value

        def initialize(action:, value:)
            action = Action[action.to_s.upcase] unless action.is_a?(Action)
            @action = action
            @value = [*value].freeze
        end

        def as_json(*)
            @json ||= {
                'action' => action.name.to_s.downcase.freeze,
                'value' => value.map(&:as_json).freeze
            }.freeze
        end

        def self.json_create(json)
            new(json['action'], [*json['value']].map{|e| Base.json_create(e) }) unless json.nil?
        end
    end
end
