module PunishmentHelper
    include ApplicationHelper
    include UserHelper

    def expire_in_words(raw = false, date = self.expire, type = self.type)
        if date.nil?
            (raw || type.nil? || type == 'ban') ? 'Never' : ''
        elsif date.to_i < Time.now.to_i
            "Expired " + time_ago_in_words(date, false, :vague => true) + " ago"
        else
            time_ago_in_words(date, false, :vague => true) + " from now"
        end
    end

    def status_in_words(user, date = self.expire, type = self.type, active = self.active?, stale = self.stale?)
        if !active
            "Inactive"
        elsif stale && self.can_distinguish_status?(:stale, user)
            "Stale"
        elsif date.nil?
            type.nil? || self.ban? ? 'Permanent' : ''
        elsif date < Time.now
            "Expired #{time_ago_in_words(date, false, :vague => true)} ago"
        else
            "Expires in #{time_ago_in_words(date, false, :vague => true)}"
        end
    end

    def short_description(user, date = self.expire, type = self.type, active = self.active?, stale = self.stale?)
        display_type = type.humanize(:capitalize => false)
        if !active
            "Inactive #{display_type}"
        elsif stale && self.can_distinguish_status?(:stale, user)
            "Stale #{display_type}"
        elsif date.nil?
            if type.nil? || self.ban?
                "Permanent #{display_type}"
            else
                display_type.capitalize
            end
        elsif date < Time.now
            "Expired #{display_type}"
        else
            display_type.capitalize
        end
    end

    def expires?(date = self.expire)
        !date.nil?
    end

    def PunishmentHelper.filter_punishments(user, *punishments)
        punishments.flatten.delete_if{|p| !p.can_index?(user)}
    end

    def link_to_punisher(punishment)
        if punishment.punisher
            link_to_user(punishment.punisher)
        else
            content_tag(:span, punishment.punisher_name, style: "color: #FA0;")
        end
    end
end
