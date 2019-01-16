module Component
    class << self
        def build(&block)
            Component::Builder.new(&block).to_component
        end

        def from_json(json)
            Component::Base.json_create(json)
        end

        def from_legacy_text(legacy, **args)
            extra = []
            ChatUtils.formatted_spans(legacy) do |text, formats|
                c = {}
                formats.each do |format|
                    if format.color?
                        c[:color] = format.name.downcase
                    else
                        case format
                            when ChatColor::BOLD
                                c[:bold] = true
                            when ChatColor::ITALIC
                                c[:italic] = true
                            when ChatColor::UNDERLINED
                                c[:underlined] = true
                            when ChatColor::STRIKETHROUGH
                                c[:strikethrough] = true
                            when ChatColor::OBFUSCATED
                                c[:obfuscated] = true
                        end
                    end
                end
                extra << Component::Text.new(text, **c)
            end

            if extra.size == 1 && args.empty?
                extra[0]
            else
                Component::Text.new('', **args.merge(extra: [*extra, *args[:extra]]))
            end
        end
    end
end
