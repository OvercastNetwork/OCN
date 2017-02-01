module ApplicationHelper
    include ActionView::Helpers::DateHelper
    include UserHelper

    def urlify(str)
        return "" if str == nil
        str.downcase.gsub(/\s+/, "").gsub(/\W+/, "")
    end

    def return_to(path)
        @return_to = path
    end

    def redirect_to_back(path = nil, **options)
        path ||= request.env['HTTP_REFERER'] if request.env['HTTP_REFERER'].present? && request.env['HTTP_REFERER'] != request.env['REQUEST_URI']
        path ||= @return_to
        path ||= session[:return_to]
        path ||= main_app.root_path

        redirect_to(path, **options)
    end

    def vague_format_time(time)
        return "Unknown" if time.nil? || time == ""
        time = time.utc
        time.strftime("%b #{time.day.ordinalize} %Y")
    end

    def format_time(time, zone: nil, show_zone: false)
        zone ||= @timezone
        time = time.in_time_zone(zone) if zone

        text = "%B #{time.day.ordinalize}, %Y - %l:%M %p"
        text += " #{time.zone}" if show_zone

        time.strftime(text)
    end

    def time_ago_in_words(time, include_seconds = false, about: false, **options)
        text = super(time, **options)
        text.gsub!(/^about /, '') unless about
        text
    end

    def time_ago_tag(time, tag: 'span', tooltip: {}, **html_options)
        html_options = html_options.merge(rel: 'tooltip', title: format_time(time), data: tooltip) if tooltip
        content = "#{time_ago_in_words(time)} ago"
        content_tag(tag, content, **html_options)
    end

    def brief_format_time(time)
        time.strftime("%F %T")
    end

    # Given total seconds, generate HH:MM[:SS]
    def format_time_of_day(t, force_seconds: false)
        if t
            t = t.to_i
            s = t % 60
            m = (t / 60) % 60
            h = t / 3600

            text = "#{h}:#{m.to_s.rjust(2, '0')}"
            text += ":#{s.to_s.rjust(2, '0')}" if s != 0 || force_seconds
            text
        end
    end

    # Parse HH[:MM[:SS]] into total seconds
    def parse_time_of_day(text)
        if text =~ /\A(\d{1,2})(:(\d{1,2}))?(:(\d{1,2}))?\z/
            $1.to_i * 3600 + $3.to_i * 60 + $5.to_i
        end
    end

    def limited_text_tag(content, limit, tag: 'span', tooltip: {}, html_options: {})
        if content.size > limit
            html_options = html_options.merge(rel: 'tooltip', title: content, data: tooltip) if tooltip
            content = "#{content[0...limit - 3]}..."
        end
        content_tag(tag, content, **html_options)
    end

    def block_banned_users
        if current_user && current_user.is_banned?
            flash[:alert] = 'Could not perform the requested action because you are banned.'
            redirect_to_back root_path
        end
    end

    def block_in_game_banned_users
        if current_user && current_user.is_in_game_banned?
            flash[:alert] = 'Could not perform the requested action because you are banned.'
            redirect_to_back root_path
        end
    end

    def is_same_user?(user)
        !user.nil? && user_signed_in? && current_user.username == (user.is_a?(User) ? user.username : user)
    end

    def user_is_admin?(user = current_user)
        user && user.admin?
    end

    def remove_hash_values(hash, target = nil)
        hash.each_value {|obj| remove_hash_values(obj, target) if obj.is_a?(Hash)}
        hash.delete_if {|key, value| value == target}
    end

    def modify_hash_values(hash, symbol)
        hash.keys.each do |key|
            if hash[key].is_a?(Hash) then
                modify_hash_values(hash[key], symbol)
            else
                begin
                    hash[key] = hash[key].respond_to?(symbol) ? hash[key].send(symbol, args) : send(symbol, hash[key])
                rescue
                    # ignored
                end
            end
        end
    end

    def to_boolean(string)
        if %w(true false 1 0).include?(string)
            %w(true 1).include?(string)
        else
            raise 'Boolean could not be derived from object.'
        end
    end

    def mc_sanitize(str)
        str.gsub(/[^0-9a-z_]/i, '')
    end

    def is_production?
        Rails.env == 'production' || Rails.env == 'staging'
    end

    def join_safe(things)
        things.to_a.join.html_safe
    end
end
