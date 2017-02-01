module Component
    class ClickEvent
        class Action < Enum
            create :OPEN_URL, :OPEN_FILE, :RUN_COMMAND, :SUGGEST_COMMAND
        end

        attr_reader :action, :value

        def initialize(action:, value:)
            action = Action[action.to_s.upcase] unless action.is_a?(Action)
            @action = action
            @value = value.to_s.freeze
        end

        def as_json(*)
            @json ||= {
                'action' => action.name.to_s.downcase.freeze,
                'value' => value
            }.freeze
        end

        def self.json_create(json)
            # TODO: error handling
            new(json['action'], json['value']) unless json.nil?
        end
    end
end
