
module EmojiHelper
    include ERB::Util # h

    # Compile a Regexp that will match any unicode emoji
    UNICODE_RE = Regexp.compile(Emoji.all.flat_map(&:unicode_aliases).map{|s| Regexp.escape(s) }.join('|'))

    def do_emoji(content, emoji_size=20)
        # Ensure content is a real String and not an ActiveSupport::SafeBuffer,
        # which has a broken #gsub method.
        content = content.to_str

        # Render named emojis e.g. :name:
        content.gsub!(/:([\w+-]+):/) do |match|
            if emoji = Emoji.find_by_alias($1)
                emoji_img(emoji, emoji_size)
            else
                match
            end
        end

        # Use emoji variation of keycap characters
        # See http://www.fileformat.info/info/unicode/char/20e3
        content.gsub! /([0-9#])\u20e3/ do |match|
            if emoji = Emoji.find_by_unicode("#{$1}\ufe0f\u20e3")
                emoji_img(emoji, emoji_size)
            else
                match
            end
        end

        # Render all other unicode emojis
        content.gsub! UNICODE_RE do |match|
            if emoji = Emoji.find_by_unicode(match)
                emoji_img(emoji, emoji_size)
            else
                match
            end
        end

        content
    end

    def emoji_img(emoji, emoji_size)
        %(<img alt="#{emoji.name}" src="#{image_path("emoji/#{emoji.image_filename}")}" style="vertical-align:middle;" width="#{emoji_size}" height="#{emoji_size}"/>)
    end
end
