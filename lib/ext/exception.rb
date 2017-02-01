class Exception
    def format_long
        "#{self.class.name}: #{self.message}\n#{self.backtrace.map{|line| "    from #{line}\n"}.join}"
    end
end
