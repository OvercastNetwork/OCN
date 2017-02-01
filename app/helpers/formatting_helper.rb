module FormattingHelper
    extend self
    include ActionView::Helpers::DateHelper

    def gender_pronoun_for(user)
        unless user.nil? || !user.is_a?(User)
            case user.gender
            when 'Male'
                return {:possessive => 'his', :singular => 'him'}
            when 'Female'
                return {:possessive => 'hers', :singular => 'her'}
            end
        end
        {:possessive => 'their', :singular => 'them'}
    end

    def safe_formatted_html(content, link_html = {:target => '_blank'}, truncate_len = 45)
        auto_link((h content).gsub(/(?:\n\r?|\r\n?)/, '<br>'), :html => link_html) do |text|
            truncate(text, :length => truncate_len)
        end
    end

    def gamemode_link(gamemode)
        PGM::Application.config.gamemodes_short_inv[gamemode]
    end

    def duration_shorthand(from, to=nil)
        if to
            from, to = to, from if to < from
            s = (to - from).to_i
        else
            s = from.to_i
        end

        text = ""

        text << "#{s / 1.day}d" if s >= 1.day
        text << "#{s % 1.day / 1.hour}h" if s >= 1.hour && s < 10.days
        text << "#{s % 1.hour / 1.minute}m" if s >= 1.minute && s < 1.day
        text << "#{s % 1.minute}s" if s < 1.hour

        text
    end

    def time_ago_shorthand(t)
        duration_shorthand(t, Time.now) if t
    end

    def brief_date(t)
        "#{t.year}-#{t.month}-#{t.day}"
    end

    def format_relative_time(time)
        text = time_ago_in_words(time)
        if time.to_date.future?
            "#{text} from now"
        else
            "#{text} ago"
        end
    end

    def format_package_expire(time)
        if time < 27.days.from_now
            time_ago_in_words(time)
        else
            diff = time - Time.now
            "#{(diff / 60 / 60 / 24).to_i} days"
        end
    end

    def format_dollars(cents:, show_cents: false)
        dollars, cents = cents.round.divmod(100)

        if show_cents || cents != 0
            sprintf("%i.%02i", dollars, cents)
        else
            dollars.to_s
        end
    end

    def format_counted(thing, count)
        "#{count} #{thing}".pluralize(count)
    end
end
