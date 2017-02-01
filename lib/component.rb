module Component
    def self.build(&block)
        Component::Builder.new(&block).to_component
    end
end
