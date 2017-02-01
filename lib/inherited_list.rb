class InheritedList
    include Enumerable

    attr :local, :parents

    def initialize(*parents)
        @local = []
        @parents = parents.reverse.freeze
    end

    def each
        if block_given?
            parents.each do |parent|
                parent.each do |e|
                    yield e
                end
            end
            local.each do |e|
                yield e
            end
        else
            enum_for :each
        end
    end

    def to_a
        [*parents.flatten, *local]
    end

    delegate :[], :size, :empty?, :hash, :eql?, :==, :inspect, :to_s, :pretty_print,
             to: :to_a

    delegate :push, :append, :<<, :unshift,
             to: :local
end
