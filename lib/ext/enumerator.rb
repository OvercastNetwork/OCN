class Enumerator
    # Test if this enumerator has more elements available by
    # calling #peek and catching any StopIteration raised.
    def more?
        peek
        true
    rescue StopIteration
        false
    end

    # Return an array of the next N elements in the enumeration,
    # or all the remaining elements if less than N are available.
    def next_n(n)
        a = []
        begin
            n.times{ a << self.next }
        rescue StopIteration
            # ignored
        end
        a
    end
end
