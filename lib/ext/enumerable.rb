module Enumerable
    # Transform self into a Hash by passing each element to the
    # given block, which must return the respective key, value
    # pair for that element.
    def mash(*keys)
        if block_given?
            h = {}
            each do |e|
                e = yield e
                if e.is_a?(Hash)
                    h.merge!(e)
                elsif e.is_a?(Array)
                    raise TypeError.new("Expected 2 return values, got #{e.size}") unless e.size == 2
                    h[e[0]] = e[1]
                else
                    raise TypeError.new("Expected Array or Hash return value, got #{e.class}")
                end
            end
            h
        elsif keys.empty?
            Hash[*to_a.flatten(1)]
        else
            keys.zip(self).mash
        end
    end

    # Merge this sorted sequence with all of the given sorted sequences
    # into a sorted sequence containing all of their combined elements.
    # All sequences involved must already be sorted.
    def collate(*seqs)
        if block_given?
            enums = [each, *seqs.map(&:each)]

            loop do
                enums.select! do |en|
                    begin
                        en.peek
                        true
                    rescue StopIteration
                        false
                    end
                end

                break if enums.empty?

                yield enums.min_by(&:peek).next
            end
        else
            enum_for :collate, *seqs
        end
    end

    # Equivalent to #collate but calls the given block on each element
    # and sorts by the natural order of the returned value. As with
    # #collate, all sequences involved must already be sorted by the
    # given criteria.
    def collate_by(*seqs)
        Enumerator.new do |results|
            enums = [each, *seqs.map(&:each)]

            loop do
                enums.select! do |en|
                    begin
                        en.peek
                        true
                    rescue StopIteration
                        false
                    end
                end

                break if enums.empty?

                results << enums.min_by{|en| yield en.peek }.next
            end
        end
    end

    def where_attrs(**attrs)
        select do |e|
            attrs.all? do |k, v|
                e.__send__(k) == v
            end
        end
    end

    def find_by_attrs(**attrs)
        detect do |e| # detect = find but less likely to collide
            attrs.all? do |k, v|
                e.__send__(k) == v
            end
        end
    end

    alias_method :asc_by, :sort_by
    def desc_by(&block)
        sort_by(&block).reverse # This is the fastest way to reverse sort, seriously
    end

    # Return the indexes of the elements for which the given block returns true
    def select_indexes
        if block_given?
            indexes = []
            each_with_index do |e, i|
                indexes << i if yield e
            end
            indexes
        else
            enum_for :select_indexes
        end
    end
end
