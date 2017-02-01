module RenderHelper
    include EmojiHelper
    include UserHelper

    def render_post(content, converted)
        content = do_markdown(do_emoji(str(content))) if converted
        do_safe(do_embeds(do_sanitize(content)))
    end

    def render_attachment(path)
        return unless path

        name = File.basename(path).sub(/#{Regexp.escape(File.extname(path))}$/, '')
        path = File.join(Rails.root, path) unless path =~ /^\//

        if File.exists?(path)
            content = File.read(path)
            content = do_markdown(content) if path =~ /\.markdown$/
            content = Haml::Engine.new(content, suppress_eval: true).render if path =~ /\.haml$/
            content = %{<div class="attachment-#{name}">#{content}</div>}
            do_safe(content)
        else
            do_safe('')
        end
    end

    def render_topic_title(content, emoji_size: 20, plain: false)
        content = content.subject if content.is_a? Forem::Topic
        do_safe(render_user_tags(do_emoji(h(content), emoji_size), plain: plain, link: false))
    end

    def render_forum_description(content, emoji_size: 14)
        content = content.description if content.is_a? Forem::Forum
        do_safe(do_markdown(do_emoji(h(content), emoji_size)))
    end

    def render_commit_message(content)
        do_safe(do_emoji(h(content)))
    end

    def render_tournament_desc(content)
        do_safe(do_markdown(do_emoji(str(content))))
    end

    def render_profile(content)
        do_safe(do_sanitize(do_emoji(str(content))))
    end

    def render_alert(content)
        do_safe(do_emoji(h(content)))
    end

    def render_gift(content)
        do_safe(do_sanitize(do_emoji(content)))
    end

    private
    def str(content)
        content.to_s
    end

    def process_markdown_custom_tags(text)
        # This will translate custom tags even inside code blocks, which we don't want,
        # but we don't have an easy to figure out exactly what will end up inside a code block.
        # We could try and scan for them ourselves, but if our parsing is not exactly the same as
        # Redcarpet's parsing (and it inevitably isn't), then we end up dumping HTML in the
        # code blocks and making a mess.
        #
        # Redcarpet supports custom renderers, and lets you subclass existing renderers,
        # but you can't call any supermethods. This means that in order to filter outside of
        # code blocks, we would also have to render everything outside of code blocks ourselves,
        # which essentially means rewriting the entire renderer.
        render_user_tags(text)
    end

    def do_markdown(content)
        process_markdown_custom_tags(MARKDOWN.render(content))
    end

    def do_sanitize(content)
        Sanitize.clean(content, Sanitize::Config::ARES)
    end

    def do_embeds(content)
        # Substitute [youtube:VIDEO_ID] shortcodes with youtube embed, allowing for optional timestamp.
        # The timestamp has to be converted from hours/minutes/seconds to seconds for YouTube's embed API.
        content.gsub(/\[youtube\:?([A-Za-z0-9_-]{6,12})(?:\?t=(?:(\d{1,2})h)?(?:(\d{1,2})m)?(?:(\d{1,2})s)?)?\]/i) do |match|
            start = $2.to_i * 3600 + $3.to_i * 60 + $4.to_i
            '<div class="embed-responsive embed-responsive-16by9"><iframe width="714" height="402" src="https://www.youtube.com/embed/' + $1 + '?rel=0&start=' + start.to_s + '" frameborder="0" allowfullscreen></iframe></div>'
        end
    end

    def do_no_html(content)
        content.gsub(/[<>]/, '')
    end

    def do_safe(content)
        content.html_safe
    end
end
