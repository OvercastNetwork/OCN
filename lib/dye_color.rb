class DyeColor
    attr_reader :name, :r, :g, :b

    def initialize(name, r, g, b)
        @name, @r, @g, @b = name, r, g, b
        self.class.by_name[name] = self
    end

    def to_html_color
        "rgb(#{r},#{g},#{b})"
    end

    class << self
        def parse(name)
            by_name[name.to_s]
        end

        alias_method :[], :parse

        def by_name
            @by_name ||= {}
        end
    end

    WHITE       = new('white',         221, 221, 221)
    ORANGE      = new('orange',        219, 125,  62)
    MAGENTA     = new('magenta',       179,  80, 188)
    LIGHT_BLUE  = new('light blue',    107, 138, 201)
    YELLOW      = new('yellow',        228, 177,  29)
    LIME        = new('lime',           65, 174,  56)
    PINK        = new('pink',          208, 132, 153)
    GRAY        = new('gray',           64,  64,  64)
    SILVER      = new('silver',        154, 161, 161)
    CYAN        = new('cyan',           46, 110, 137)
    PURPLE      = new('purple',        126,  61, 181)
    BLUE        = new('blue',           46,  56, 141)
    BROWN       = new('brown',          79,  50,  31)
    GREEN       = new('green',          53,  70,  27)
    RED         = new('red',           150,  52,  48)
    BLACK       = new('black',          25,  22,  22)
end
