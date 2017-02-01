class User
    module Groups
        extend ActiveSupport::Concern
        include Group::Member

        included do
            before_validation :repair_memberships

            # Array of flairs, in display order. Realms may be repeated.
            # [{realm:, text:}, {realm:, text:}, ...]
            api_synthetic :minecraft_flair do
                badge_groups.reverse.flat_map do |group|
                    group.minecraft_flair.map do |realm, flair|
                        {
                            realm: realm,
                            text: "#{ChatColor[flair.color]}#{flair.symbol}",
                            priority: group.priority,
                        }
                    end
                end
            end
        end # included do

        # Occasionally, a seemingly random user will have the group_id of their
        # first membership replaced by a newly created ObjectId that does not
        # belong to any group. We have no idea what is doing this or how.
        #
        # The group field on Membership is validated, but whatever is doing this
        # somehow bypasses validations. Once this happens to a User, the document
        # can't be saved and will cause validation errors all over the place.
        #
        # After a lot of investigation, we just gave up and added this callback
        # to fix the problem and generate a Sentry event for the record.
        def repair_memberships
            bad = memberships.select do |m|
                m.group_id && m.group.nil?
            end

            bad.each do |m|
                Raven.capture_message("Deleting bad membership for user #{username} (#{id})\n#{m.inspect}")
                memberships.delete(m)
            end
        end

        def badge_memberships
            premium = false
            active_memberships.reduce([]) do |list, m|
                if m.group.premium?
                    next list if premium
                    premium = true
                end
                list << m
                list
            end
        end

        def badge_groups
            badge_memberships.map(&:group)
        end

        def html_color
            group = active_groups.to_a.find(&:html_color)
            group ||= Group.default_group
            group.html_color_css
        end
    end # Groups
end
