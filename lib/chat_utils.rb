module ChatUtils
    SPACER = "\u205a" # ⁚

    CHAR_WIDTHS = Hash.new{ 5 }.merge(
        'I' => 3,
        'f' => 4,
        'i' => 1,
        'k' => 4,
        'l' => 2,
        't' => 3,
        '!' => 1,
        '.' => 1,
        ',' => 1,
        ';' => 1,
        ':' => 1,
        '|' => 1,
        '\\' => 2,
        '[' => 3,
        ']' => 3,
        ' ' => 3,
        '*' => 4,
        '(' => 4,
        ')' => 4,
        '{' => 4,
        '}' => 4,
        '<' => 4,
        '>' => 4,
        '@' => 6,
        "\n" => 0,
        SPACER => 0,
        "\u2550" => 8, # ═
        "\u2554" => 8, # ╔
        "\u2557" => 8, # ╗
        "\u255a" => 8, # ╚
        "\u255d" => 8, # ╝
        "\u27a0" => 7, # ➠
        "\u2603" => 8, # snowman
        "\u273b" => 7, # snowflake
    )

    class << self
        def formatted_spans(text, include_empty: false)
            format = []
            text.split(/(\u00a7+.)/).each do |s|
                if s =~ /\u00a7+(.)/ && cc = ChatColor.by_code[$1]
                    format.clear if cc.reset?
                    format << cc unless cc == ChatColor::RESET || format.include?(cc)
                elsif !s.empty? || include_empty
                    yield s, format.dup
                end
            end
        end

        def pixel_width(text)
            pixels = 0
            chars = 0

            formatted_spans(text) do |text, format|
                span_pixels = text.chars.map{|c| CHAR_WIDTHS[c] }.sum
                span_chars = text.chars.size
                pixels += span_pixels
                chars += span_chars
                pixels += span_chars if format.include?(ChatColor::BOLD)
            end

            pixels + chars - 1
        end

        def padded_heading(left, center, right, width:, pad: ' ', pad_color: ChatColor::RESET, spacer: SPACER, spacer_color: ChatColor::BLACK)
            pad_width = pixel_width(pad) + 1
            fill_width = width - pixel_width("#{pad_color}#{left}§r #{center}§r #{pad_color}#{right}")
            pads_per_side = (fill_width / (pad_width * 2)).floor
            spacers_per_side = (fill_width - pad_width * pads_per_side * 2).to_f / 2.0
            [
                pad_color, left, pad * pads_per_side,
                spacer_color, spacer * spacers_per_side.floor,
                "§r #{center}§r ",
                spacer_color, spacer * spacers_per_side.ceil,
                pad_color, pad * pads_per_side, right
            ].join
        end
    end
end
