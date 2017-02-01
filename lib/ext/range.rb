class Range
    def delta
        self.end - self.begin
    end

    def clamp(v)
        if v < self.begin
            self.begin
        elsif !cover?(v)
            self.end
        else
            v
        end
    end

    def lerp(c)
        self.begin + (c * delta)
    end

    def lerp_range(a, b = nil)
        if b.nil?
            lerp(a.begin)..lerp(a.end)
        else
            lerp(a)..lerp(b)
        end
    end

    def subdivide(count)
        if block_given?
            step = 1.0 / count
            count.times do |i|
                yield lerp_range(i * step, (i + 1) * step)
            end
        else
            enum_for :subdivide, count
        end
    end

    def intersect(r)
        a = [self.begin, r.begin].max
        b = [self.end, r.end].min
        if (self.end <= r.end && self.exclude_end?) || (r.end <= self.end && r.exclude_end?)
            a...b
        else
            a..b
        end
    end
end
