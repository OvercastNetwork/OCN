class ChatColor
    COLOR_CHAR = "\u00a7"

    attr_reader :code

    def initialize(name, code, html: nil, aliases: [])
        @name = name
        @code = code
        @html = html

        self.class.by_name[name] = self
        self.class.by_code[code] = self

        aliases.each do |al|
            self.class.by_alias[al] = self
        end
    end

    def name
        @name
    end

    def inspect
        "<#{self.class.name}:#{name}>"
    end
    
    def +(str)
        to_str + str
    end

    def to_str
        COLOR_CHAR + @code.to_s
    end
    
    def to_s
        self.to_str
    end

    def to_html
        @html
    end

    def color?
        @code =~ /[0-9a-f]/
    end

    def reset?
        @code == 'r' || color?
    end

    class << self
        def color_char
            COLOR_CHAR
        end

        def by_name
            @by_name ||= {}
        end

        def by_alias
            @by_alias ||= {}
        end

        def by_code
            @by_code ||= {}
        end

        def const_missing(key)
            self[key] or super
        end

        def each
            by_name.each {|key, value| yield(key, value)}
        end

        def parse(name)
            name = name.to_s.strip.gsub(/\s+/, '_').upcase.to_sym
            by_name[name.to_sym] || by_alias[name.to_sym]
        end

        def parse!(name)
            parse(name) or raise ArgumentError, "Unknown color '#{name}'"
        end
        alias_method :[], :parse!

        def names
            by_name.keys
        end
    end

    ChatColor.new :BLACK,          '0', html: '#000'
    ChatColor.new :DARK_BLUE,      '1', html: '#008'
    ChatColor.new :DARK_GREEN,     '2', html: '#080'
    ChatColor.new :DARK_AQUA,      '3', html: '#088'
    ChatColor.new :DARK_RED,       '4', html: '#800'
    ChatColor.new :DARK_PURPLE,    '5', html: '#808'
    ChatColor.new :GOLD,           '6', html: '#f92'
    ChatColor.new :GRAY,           '7', html: '#aaa'
    ChatColor.new :DARK_GRAY,      '8', html: '#666'
    ChatColor.new :BLUE,           '9', html: '#00f'
    ChatColor.new :GREEN,          'a', html: '#0d2'
    ChatColor.new :AQUA,           'b', html: '#0bd'
    ChatColor.new :RED,            'c', html: '#f00'
    ChatColor.new :LIGHT_PURPLE,   'd', html: '#f0f'
    ChatColor.new :YELLOW,         'e', html: 'rgb(228,177,29)'
    ChatColor.new :WHITE,          'f', html: '#ddd'
    ChatColor.new :OBFUSCATED,     'k', aliases: [:MAGIC]
    ChatColor.new :BOLD,           'l'
    ChatColor.new :STRIKETHROUGH,  'm'
    ChatColor.new :UNDERLINED,     'n', aliases: [:UNDERLINE]
    ChatColor.new :ITALIC,         'o'
    ChatColor.new :RESET,          'r'

    COLORS = 16.times.map{|n| by_code[n.to_s(16)] }.freeze

    FLAGS = [BOLD, ITALIC, UNDERLINED, STRIKETHROUGH, OBFUSCATED].freeze

    by_name.freeze
    by_alias.freeze
    by_code.freeze
end
