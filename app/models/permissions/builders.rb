module Permissions
    module Builders
        class Builder
            def initialize(&block)
                instance_exec(&block)
            end
        end

        class Root < Builder
            attr_reader :domains

            def initialize(&block)
                @domains = {}
                super(&block)
            end

            def schema
                Schema.new(build)
            end

            def build
                @domains.mash do |name, domain|
                    {name => domain.build}
                end
            end

            protected

            def domain(name, &block)
                @domains[name.to_sym] = Branch.new(&block)
            end
        end

        class Branch < Builder
            attr_reader :prefix, :nodes

            def initialize(prefix: [], nodes: nil, &block)
                @prefix = prefix
                @nodes = nodes || []
                super(&block)
            end

            def build
                @nodes.map(&:build)
            end

            protected

            def qualify(symbol)
                [*@prefix, *symbol]
            end

            def branch(symbol, &block)
                Branch.new(prefix: qualify(symbol), nodes: @nodes, &block)
            end

            def node(symbol, display = nil, &block)
                @nodes << Node.new(qualify(symbol), display, &block)
            end
        end

        class Node < Builder
            attr_reader :symbol, :display, :options

            def initialize(symbol, display, &block)
                @symbol = [*symbol].map(&:to_s)
                @display = display
                @options = []
                super(&block)
            end

            def build
                {
                    symbol: symbol,
                    options: {
                        array: options.map(&:build),
                        default: 0,
                    },
                    display: display,
                }
            end

            protected

            def option(symbol, display = nil)
                @options << Option.new(symbol, display)
            end
        end

        class Option
            attr_reader :symbol, :display

            def initialize(symbol, display = nil)
                @symbol = symbol
                @display = display
            end

            def build_symbol
                if @symbol.is_a?(Symbol)
                    @symbol.to_s
                else
                    @symbol
                end
            end

            def build
                {
                    symbol: build_symbol,
                    display: @display,
                }
            end
        end

        module NodeMacros
            def abstainable(symbol, display = nil, &block)
                node symbol, display do
                    option :abstain, ""
                    instance_exec(&block) if block
                end
            end

            def boolean(symbol, display = nil, &block)
                abstainable symbol, display do
                    option true, "Yes"
                    option false, "No"
                    instance_exec(&block) if block
                end
            end

            def ownable(symbol, display = nil, &block)
                abstainable symbol, display do
                    option :all, "All"
                    option :own, "Own"
                    option :none, "None"
                    instance_exec(&block) if block
                end
            end

            def involvable(symbol, display = nil, &block)
                ownable symbol, display do
                    option :involved, "Involved"
                    instance_exec(&block) if block
                end
            end
        end

        class Branch
            include NodeMacros
        end
    end
end
