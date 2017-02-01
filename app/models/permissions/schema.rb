module Permissions
    class Schema
        attr :permissions
        attr :generic_permission_domains
        attr :field_permission_domains

        def initialize(permissions)
            @permissions = permissions

            @generic_permission_domains = [:forum, :group]

            @field_permission_domains = {
                punishment: {
                    model: Punishment,
                    options: ['all', 'own']
                },
                generic_group: {
                    model: Group,
                    options: [true, false]
                }
            }
        end

        # Permission that everybody has
        def everybody_permission
            ['global', 'everybody', true]
        end

        def field_permission_exists?(domain, field, option)
            if field_perms = field_permission_domains[domain.to_sym]
                field_perms[:model].accessible_attributes.include?(field.to_s) && field_perms[:options].include?(option)
            end
        end

        def normalize_node(node)
            case node
                when Enumerable
                    # Flatten nested node lists
                    node.flat_map{|n| normalize_node(n) }
                when Mongoid::Document
                    # Convert model instances to their ID
                    [node.id.to_s]
                when TrueClass, FalseClass
                    [node]
                else
                    # Expand dotted notation e.g. "a.b.c" -> ["a", "b", "c"]
                    node.to_s.split(/\./)
            end
        end

        def expand_without_assert(*nodes)
            nodes.flat_map do |node|
                normalize_node(node)
            end
        end

        def expand(*permission)
            permission = expand_without_assert(*permission)
            assert_permission_exists(*permission)
            permission
        end

        def generic_permission?(domain, *)
            domain && generic_permission_domains.include?(domain.to_sym)
        end

        def field_permission?(_, verb = nil, *)
            verb && verb.to_s == 'edit'
        end

        def permission_exists?(*permission)
            permission = expand_without_assert(*permission)
            domain, *symbol, option = permission
            domain = domain.to_sym

            if generic_permission?(domain)
                permission_exists?("generic_#{domain}", *symbol[1..-1], option)
            elsif field_permission?(*permission) && field_permission_exists?(domain, symbol[1], option)
                true
            elsif actions = permissions[domain]
                if action = actions.find{|a| a[:symbol] == symbol}
                    option.nil? || action[:options][:array].find{|o| o[:symbol] == option }
                end
            end
        end

        def assert_permission_exists(*perm)
            perm = expand_without_assert(*perm)
            permission_exists?(*perm) or raise ArgumentError, "Unknown permission #{perm.inspect}"
        end

        # For each valid permission, yields perm, description, {value => description}
        def each_permission
            if block_given?
                permissions.each do |domain, actions|
                    actions.each do |action|

                        yield [domain.to_s, *action[:symbol].map(&:to_s)],
                            action[:options][:array].mash{|option| [option[:symbol], option[:display]] },
                            action[:display]
                    end
                end
            else
                enum_for :each_permission
            end
        end

        def pretty_permissions
            lines = each_permission.map do |symbol, options, description|
                if symbol[0] =~ /^generic_(.*)/
                    symbol = [$1, '*', *symbol[1..-1]]
                end
                [symbol.join('.'), options.keys.join(','), description]
            end

            symbol_width = lines.map{|line| line[0].size }.max
            options_width = lines.map{|line| line[1].size }.max

            lines.map do |symbol, options, description|
                "#{symbol.ljust(symbol_width)}   #{options.ljust(options_width)}   #{description}\n"
            end.join
        end
    end
end
