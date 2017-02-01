class String
    def is_strictly_alphanumeric?(whitespace_allowed = false)
        self =~ (whitespace_allowed ? /^[A-Za-z0-9 ]+$/ : /^[A-Za-z0-9]+$/)
    end

    def parse_bool
        ['true', '1', 'yes', 'on', 't'].include? self
    end

    def first_group(re)
        self =~ re and $1
    end

    def slugify(whitespace: '_', allow: '')
        strip.downcase.gsub(/[^a-z0-9#{allow}#{whitespace}]+/, whitespace)
    end

    def mangle_method_name(key)
        self =~ /^([^!?]*)([!?]*)$/
        "#{$1}__#{key}#{$2}"
    end
end
