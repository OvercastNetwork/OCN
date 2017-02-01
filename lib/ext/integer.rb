class Integer
    def zpad(width)
        to_s.rjust(width, '0')
    end

    def infinite?
        false
    end

    def finite?
        !infinite?
    end

    def nan?
        false
    end
end
