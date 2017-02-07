module UserHelper
    module Global
        def avatar_for(user, size, radius: 3, style: {}, hover: false, plain: false, link: false, glow: false, name: nil)
            return '' if plain

            url = avatar_url_for(user, size)
            name ||= user.username if user.respond_to? :username

            style = {
                'width'         => "#{size}px",
                'height'        => "#{size}px",
                'border-radius' => "#{radius + (size - 1) / 32}px", # Approximation to allow corners to scale with size
            }.merge(style)

            attrs = {
                style: style.map{|k, v| "#{k}: #{v};" }.join,
                width: size,
                height: size,
                class: ['avatar'],
                src: url,
                alt: name,
                title: name,
            }

            attrs[:rel] = 'tooltip' if hover
            attrs[:class] << 'glow' if glow && user.last_sighting_by.try!(:online?)

            html = tag(:img, attrs)
            html = content_tag(:a, html, href: user_path(user || name)) if link
            html
        end

        def avatar_url_prefix_for(user, local: true)
            if user.nil?
                user = "Steve"
            elsif user.respond_to? :uuid
                user = user.uuid
            end

            if local && Rails.configuration.local_avatars
                "http://localhost:3005/#{user}"
            else
                "#{Rails.configuration.avatar_base_url}/#{user}"
            end
        end

        def avatar_url_for(user, size, local: true)
            "#{avatar_url_prefix_for(user, local: local)}?size=#{size}"
        end

        def user_path?(path)
            route = Rails.application.routes.recognize_path(path)
            route[:controller] == 'users' &&
                route[:action] == 'show' &&
                path.downcase !~ /^\/forums/ # recognize_path doesn't work with engines
        rescue ActionView::Template::Error, ActionController::RoutingError # Raised by recognize_path if it doesn't like the path
            false
        end

        def user_path(user)
            user = user.username if user.respond_to? :username
            path = "/#{user}"

            if user_path?(path)
                path
            else
                "/users/#{user}"
            end
        end

        def html_color(user)
            user.html_color
        end

        PROFILE_URL_REGEX = %r<http(?:s?)://#{Regexp.quote(ORG::DOMAIN)}/(?:users/)?(\w{1,16})\b>
        AVATAR_URL_REGEX = %r<http(?:s?)://avatar\.#{Regexp.quote(ORG::DOMAIN)}/(\w{1,16})\b>

        def transform_user_tags(text)
            text.gsub(/\[(user|avatar|avatar[_-]user):(\w{1,16}|[0-9a-fA-F-]{32,})\]/) do |tag|
                type = $1
                who = $2
                if user = User.by_uuid(who) || User.by_past_username(who)
                    yield type, user
                else
                    tag
                end
            end
        end

        def transform_profile_urls(text)
            text.gsub(%r<http(?:s?)://#{Regexp.quote(ORG::DOMAIN)}/(?:users/)?(\w{1,16})\b>).each do |url|
                begin
                    username = $1
                    uri = URI.parse(url)
                    if user_path?(uri.path) and user = User.by_past_username(username)
                        yield user
                    else
                        url
                    end
                rescue URI::InvalidURIError
                    url
                end
            end
        end

        def transform_avatar_url_prefixes(text)
            text.gsub(%r<http(?:s?)://avatar\.#{Regexp.quote(ORG::DOMAIN)}/(\w{1,16})\b>).each do |url|
                username = $1
                if user = User.by_past_username(username)
                    yield user
                else
                    url
                end
            end
        end

        def normalize_user_urls(text)
            text = transform_profile_urls(text, &:permalink)

            text = transform_avatar_url_prefixes(text) do |user|
                avatar_url_prefix_for(user, local: false)
            end

            transform_user_tags(text) do |type, user|
                "[#{type}:#{user.uuid}]"
            end
        end
    end

    include Global
    extend Global

    # Everything below here is only usable from a controller

    def render_user_tags(text, plain: false, link: true)
        transform_user_tags(text) do |type, user|
            [(avatar_for(user, 20, plain: plain, link: link) if type =~ /avatar/),
             (render_user(user, plain: plain, link: link) if type =~ /user/)].join(' ')
        end
    end

    def render_user(user, plain: false, link: false, disguise: false, **html_options)
        if user
            if plain
                user.username
            else
                style = html_options.delete(:style)
                html_options[:class] = 'disguised' if disguise && user.disguised_to_anybody? && !user.disguised_to?
                if link
                    link_to(user.username, user_path(user), style: "color: #{html_color(user)}; #{style}", **html_options)
                else
                    content_tag(:span, user.username, style: "color: #{html_color(user)}; #{style}", **html_options)
                end
            end
        else
            ''
        end
    end

    def link_to_user(user, **html_options)
        render_user(user, link: true, disguise: true, **html_options)
    end

    def render_badge(user, group, tooltip: nil)
        return '' unless group.has_badge?

        case group.badge_type
            when 'youtube'
                if channel = user.channels_for(:youtube).first
                    icon = image_tag('youtube36.png', width: 26, height: 18)
                    link_to(icon, channel.url, target: '_blank', rel: 'tooltip', title: 'YouTube channel')
                end
            else
                attrs = {
                    class: 'label',
                    style: "background-color: #{group.badge_color || 'black'}; color: #{group.badge_text_color || 'white'}"
                }

                if tooltip
                    attrs[:rel] = 'tooltip'
                    attrs[:title] = tooltip
                end

                if group.badge_link
                    link_to(group.name.singularize, group.badge_link, **attrs)
                else
                    content_tag(:span, group.name.singularize, **attrs)
                end
        end
    end

    def link_to_youtube_channel(user)
        if channel = user.channels_for(:youtube).first
            link_to channel.name, channel.url, target: '_blank'
        end
    end
end
