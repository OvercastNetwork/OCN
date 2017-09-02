module StatsHelper
    def format_playing_time(len)
        orig = len

        days    = (len / 1.day).to_i
        len    -= days * 1.day
        hours   = (len / 1.hour).to_i
        len    -= hours * 1.hour
        minutes = (len / 1.minute).to_i
        len    -= minutes * 1.minute
        seconds = (len / 1.second).to_i

        seconds = seconds.to_s + " second" + (seconds == 1 ? "" : "s")
        minutes = minutes.to_s + " minute" + (minutes == 1 ? "" : "s")
        hours   = hours.to_s   + " hour"   + (hours   == 1 ? "" : "s")
        days    = days.to_s    + " day"    + (days    == 1 ? "" : "s")

        if orig < 1.minute
            "#{seconds}"
        elsif orig < 1.hour
            "#{minutes}, #{seconds}"
        elsif orig < 1.day
            "#{hours}, #{minutes}"
        else
            "#{days}, #{hours}"
        end
    end

    def mega_stat(num)
        num >= 100_000
    end    
    def big_stat(num)
        num >= 1_000
    end
end
