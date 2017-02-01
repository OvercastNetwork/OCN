module Mattermost
    module Formatting
        def image_url(path)
            ActionController::Base.helpers.image_url(path)
        end

        def image(url, alt = "")
            "![#{alt}](#{url})"
        end

        def gravatar(email, size = 18)
            image(Gravatar.url(email, size))
        end

        def link(text, url)
            "[#{text}](#{url})"
        end

        def preview(body)
            unless body.blank?
                lines = body.lines.map(&:chomp)
                pre = lines[0]
                if lines.size > 1
                    pre += " [...]"
                end
                pre
            end
        end

        def blockquote(header, body)
            if body.blank?
                header
            else
                "#{header}:\n#{body.lines.map{|line| "> #{line.chomp}\n" }}"
            end
        end
    end
end
