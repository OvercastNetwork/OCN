class Sanitize
    module Config
        ARES = {
            :elements => %w[
                a abbr b bdo blockquote br caption cite code col colgroup dd del dfn div dl
                dt em figcaption figure h1 h2 h3 h4 h5 h6 hgroup i img ins kbd li mark
                ol p pre q rp rt ruby s samp small strike strong sub sup table tbody td
                tfoot th thead time tr u ul var wbr
            ],

            :attributes => {
                :all         => ['dir', 'lang', 'title', 'class', 'style'],
                'a'          => ['href'],
                'blockquote' => ['cite'],
                'col'        => ['span', 'width'],
                'colgroup'   => ['span', 'width'],
                'del'        => ['cite', 'datetime'],
                'img'        => ['align', 'alt', 'height', 'src', 'width'],
                'ins'        => ['cite', 'datetime'],
                'ol'         => ['start', 'reversed', 'type'],
                'q'          => ['cite'],
                'table'      => ['summary', 'width'],
                'td'         => ['abbr', 'axis', 'colspan', 'rowspan', 'width'],
                'th'         => ['abbr', 'axis', 'colspan', 'rowspan', 'scope', 'width'],
                'time'       => ['datetime', 'pubdate'],
                'ul'         => ['type']
            },

            :protocols => {
                'a'          => {'href' => ['ftp', 'http', 'https', 'mailto', :relative]},
                'blockquote' => {'cite' => ['http', 'https', :relative]},
                'del'        => {'cite' => ['http', 'https', :relative]},
                'img'        => {'src'  => ['http', 'https', :relative]},
                'ins'        => {'cite' => ['http', 'https', :relative]},
                'q'          => {'cite' => ['http', 'https', :relative]}
            },

            :classes => [
                "modal",
                "pull-right",
                "navbar-fixed-top",
                "tooltip",
                "carousel-control",
                "container",
                "modal-backdrop",
                "dropdown-backdrop",
                "icon-spin",
                "carousel-indicators",
                "trophy",
                "dropdown-menu",
                "nav",
                "fa-spin",
                "fa-li",
                "fa-stack-1x",
                "fa-stack-2x",
                "tooltip-arrow",
                "popover",
                "arrow",
                "carousel-caption",
                "shop-promo",
                "host-promo",
                "tipsy",
                "tipsy-arrow",
                "peek-rblineprof-modal",
                "peek-dropdown",
            ] + ((1..12).to_a.map {|i| "span" + i.to_s }),

            :styles => [
                "position",
                "transform",
                "transform-origin",
                "cursor",
                "max-height",
            ] + %w(webkit moz ms o).map {|v| "-" + v + "-transform"} +
                %w(webkit moz ms o).map {|v| "-" + v + "-transform-origin"},

            :transformers_breadth => [
                lambda do |env|
                    node = env[:node]

                    classes = node.remove_attribute("class")
                    return if classes == nil

                    classes = classes.to_s.downcase.split(' ')
                    classes.delete_if {|val| Sanitize::Config::ARES[:classes].include?(val)}

                    node["class"] = classes.join(' ')
                end,

                lambda do |env|
                    node = env[:node]

                    styles = node.remove_attribute("style")
                    return if styles == nil

                    final = ""
                    results = Array.new

                    # remove special characters, we need "/()." for urls, "-" for properties "#," for colors, "%" for sizes
                    parsed = styles.to_s.downcase.gsub(/[^0-9a-z:;.#,%\-\/\(\)]/i, '').split(';')
                    parsed.each do |k|
                        next if k.blank?
                        style, value = k.split(':', 2)
                        style.gsub!(/[^a-z\-]/i, '')

                        results << [style, value]
                    end

                    results.each do |result|
                        next if Sanitize::Config::ARES[:styles].include?(result[0]) || result[1].to_i < 0
                        final += result[0].to_s + ':' + result[1].to_s + ';'
                    end

                    node["style"] = final
                end
            ]
        }
    end
end
