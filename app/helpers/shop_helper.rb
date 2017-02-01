module ShopHelper
    def sale_days_left
        over = Time.parse("2015/01/7")
        now = Time.now
        days = (over - now).to_i / 1.day + 1

        days < 0 ? 0 : days
    end

    def sale_days_class
        days = sale_days_left
        if days >= 7
            "badge-success"
        elsif days >= 4
            "badge-warning"
        else
            "badge-important"
        end
    end

    def sale_message
        "20% off! #{sale_days_left} day" + (sale_days_left != 1 ? "s" : "") + " left!"
    end

    def raindrops_for(total)
        steps = [5, 10]
        max = steps.max
        raindrops = []
        count = 10

        while (max * count) < total
            steps.each do |step|
                raindrops << {:value => step * count, :display => number_with_delimiter(step * count)}
            end
            count *= max
        end

        raindrops << {:value => total.to_i, :display => number_with_delimiter(total.to_i)}

        return raindrops
    end
end
