module Component
    class Base
        FLAGS = ChatColor::FLAGS.map{|c| c.name.downcase }

        attr_reader :color, :extra, :click_event, :hover_event

        class << self
            def assert_flag(flag)
                FLAGS.include?(flag) or raise ArgumentError, "Unknown formatting flag '#{flag}'"
            end
        end

        def get_flag(flag)
            Base.assert_flag(flag)
            instance_variable_get("@#{flag}")
        end

        FLAGS.each do |flag|
            define_method "#{flag}?" do
                get_flag(flag)
            end
        end

        def initialize(color: nil, extra: [], click_event: nil, hover_event: nil, **flags)
            color = ChatColor[color.to_s] unless color.nil? || color.is_a?(ChatColor)

            click_event = ClickEvent.new(**click_event) unless click_event.nil? || click_event.is_a?(ClickEvent)
            hover_event = HoverEvent.new(**hover_event) unless hover_event.nil? || hover_event.is_a?(HoverEvent)

            @color = color
            @extra = extra.freeze
            @click_event = click_event
            @hover_event = hover_event

            flags.each do |flag, value|
                Base.assert_flag(flag)
                instance_variable_set("@#{flag}", value)
            end
        end

        def as_json(*)
            @json ||= full_json.freeze
        end

        def self.json_create(json)
            new(**json_create_args(json))
        end

        protected

        def full_json
            json = {}

            json.merge!('color' => color.name.downcase.to_s) unless color.nil?

            FLAGS.each do |flag|
                value = get_flag(flag)
                json.merge!(flag.to_s => value) unless value.nil?
            end

            json.merge!('clickEvent' =>  click_event.as_json) unless click_event.nil?
            json.merge!('hoverEvent' =>  hover_event.as_json) unless hover_event.nil?
            json.merge!('extra' => extra.map(&:as_json)) unless extra.empty?

            json
        end

        def self.json_create_args(json)
            {
                color: json['color'],
                click_event: ClickEvent.json_create(json['clickEvent']),
                hover_event: HoverEvent.json_create(json['hoverEvent']),
                extra: [*json['extra']].map{|e| json_create(e) },
                **json.symbolize_keys.slice(FLAGS)
            }
        end
    end
end
