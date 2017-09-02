class UsersController < ApplicationController
    include IpHelper
    before_filter :find_user, only: [:show, :teleport]

    ENCOUNTERS = 48

    def show
        if @player.username != params[:name]
            return redirect_to request.fullpath.gsub(params[:name], @player.username)
        end

        @same_user = is_same_user?(@player)

        # Force validation to repair bad group memberships, and possibly catch other problems
        @player.validate!

        return render "suspended" unless @player.display_profile_to?

        current_time = Time.now

        @usernames = @player.usernames.asc(:created_at)
        if @usernames.size >= 2 && current_time - @usernames[-1].created_at < Rails.configuration.username_change_transition_time
            @previous_username = @usernames[-2].exact
        end

        @last_sighting = @player.last_sighting_by
        @show_server = @last_sighting && @player.display_server_to?
        latest_visible = @player.last_seen_by

        @stats = @player.stats
        @families = {"Project Ares" => "pgm-public", "Mini" => "mini", "Blitz" => "blitz-public", "Ghost Squadron" => "gs-public"}

        @initial_join = @player.initial_join.nil? ? current_time : @player.initial_join
        @days_here = ((Time.now - @initial_join) / 60 / 60 / 24).round
        @hours_played = (@stats.stat(:playing_time).to_f / 1000 / 60 / 60).round
        @teams_joined = @player.participations.count
        @cake_years = current_time.year - @initial_join.year
        @cake_day = !@initial_join.nil? && current_time.month == @initial_join.month && current_time.day == @initial_join.day && @cake_years > 0

        @friends = User.in(id: @player.friendships.shuffle[0...16].flat_map(&:user_ids) - [@player.id])
        @mutual_friends = Friendship.mutual_friends(current_user, @player) unless !user_signed_in? || @same_user

        @ranking = Ranking.find_or_initialize_by_user(@player)
        if @ranking.qualified?
            @ordinal = @ranking.ordinal
            if @ordinal > 9999
                @ordinal = nil
            else
                @ordinal_page = 1 + (@ordinal - 1) / PGM::Application.config.global_per_page
            end
        end

        @engagements = @player.engagements.ignored(false).family(Ranking::FAMILY_ID).lte(match_joined_at: latest_visible).desc(:match_joined_at).limit(40)

        @maps = Map.author(@player).loaded.order_by_rating.default_variants.select(&:can_view?)
        @show_map_ratings = true

        @kills = []
        @deaths = []
        kills_query = Death.killer(@player).lte(date: latest_visible).desc(:date).each
        deaths_query = Death.killed(@player).lte(date: latest_visible).desc(:date).each

        # Fetch batches of kills and deaths until we have ENCOUNTERS of each.
        # We don't know how many to fetch in advance because any amount
        # of them could be filtered out by nickname rules. We need User
        # objects to decide if a Death should be filtered, but we need
        # a whole batch of Deaths to fetch Users efficiently.
        while @kills.size < ENCOUNTERS || @deaths.size < ENCOUNTERS
            kills = deaths = []
            kills = kills_query.next_n(ENCOUNTERS) if @kills.size < ENCOUNTERS
            deaths = deaths_query.next_n(ENCOUNTERS) if @deaths.size < ENCOUNTERS

            both = [*kills, *deaths]
            break if both.empty?

            Death.join_users(both)
            kills.select!{|d| d.victim_obj && d.date <= d.victim_obj.last_seen_by }
            deaths.select!{|d| d.killer_obj && d.date <= d.killer_obj.last_seen_by }

            @kills += kills[0...(ENCOUNTERS - @kills.size)]
            @deaths += deaths[0...(ENCOUNTERS - @deaths.size)]
        end

        # Merge the kills and deaths into a sorted list of encounters. Because
        # we have ENCOUNTERS of each type, we are guaranteed to have enough.
        @encounters = [*@kills, *@deaths].sort_by{|d| -d.date.to_i }[0...ENCOUNTERS]
        Death.join_matches(@encounters)

        @forum_posts = Forem::Post.latest_by(@player).count
        @topics_created = Forem::Topic.latest_by(@player).count

        @objectives = [Objective::WoolPlace, Objective::CoreBreak, Objective::DestroyableDestroy].map do |klass|
            q = klass.user(@player).lte(date: latest_visible)
            [klass, q.count, q.desc(:date).limit(24).to_a]
        end.reject{|_, count, _| count == 0 }.sort_by{|_, count, _| -count }
        Objective::Base.join_matches(@objectives.flat_map{|_, _, objs| objs})

        @md5 = ""
        @wool_count = 0
        @core_count = 0

        @punishments = Punishment.punished(@player).desc(:date).hint(Punishment::INDEX_punished_date)
        scope = @same_user ? 'own' : 'all'
        @punishments = @punishments.to_a.select { |x| x.can_index?(current_user) }

        unless @punishments.empty?
            @displayed_statuses = %w()
            %w(inactive contested automatic stale).each do |status|
                @displayed_statuses << status if Punishment.can_distinguish_status?(status, scope, current_user)
            end
        end

        @appeals = Appeal.punished_viewable_by(@player).limit(10)

        @reports = {
            "Recent website reports for " => Report.web.reported_viewable_by(@player),
            "Recent website reports by " => Report.web.reporter_viewable_by(@player),
            "Recent in-game reports for " => Report.game.reported_viewable_by(@player),
            "Recent in-game reports by " => Report.game.reporter_viewable_by(@player),
        }.mash{ |heading, criteria|
            [heading, criteria.limit(10).prefetch(:reporter, :reported, 'last_action.user').to_a]
        }

        if @stats.stat(:kills) >= 10000
            Trophy['10k-kills'].give_to(@player)
        end

        if @stats.stat(:kills) >= 100000
            Trophy['100k-kills'].give_to(@player)
        end

        @trophy_count = @player.trophies.count

        @alts_final = @player.alts if current_user && current_user.can_index_alts?('all')

        @actions = []
        @actions << ["Edit profile", :get, edit_admin_user_path(@player.uuid)] if current_user_safe.admin? && @player.uuid
        @actions << ["Create a report", :get, "/reports/new/#{@player.username}"] if @player != current_user && Report::can_index?('all',current_user)
        @actions << ["Issue an infraction", :get, "/punishments/new/#{@player.username}"] if @player != current_user && Punishment::can_manage?(current_user_safe)
        @actions << ["Become user", :post, become_admin_user_path(@player.uuid)] if @player != current_user && current_user_safe.admin? && @player.uuid
        @actions << ["View topics", :get, forem.my_topics_path(:user => @player.username)] if current_user_safe.has_permission?('misc', 'player', 'view_topics', true)
        @actions << ["View posts", :get, forem.my_posts_path(:user => @player.username)] if current_user_safe.has_permission?('misc', 'player', 'view_posts', true)
    end

    def leaderboard
        @rankings = a_page_of(Ranking.leaderboard)
        @per_page = PGM::Application.config.global_per_page
    end

    def new_players
        return not_found unless current_user_safe.has_permission?('misc', 'player', 'view_new_players', true)
        @players = User.desc(:id).limit(20)
        @can_teleport = @players.any?{|p| current_user_safe.can_teleport_to?(p)}
    end

    def stats
        @times = {
            "day" => "the last 24 hours",
            "week" => "the last 7 days",
            "eternity" => "all time"
        }
        @families = {
            "global" => "all games"
        }
        @sorts = {
            "kills" => "kills",
            "deaths" => "deaths",
            "deaths_player" => "killed",
            "playing_time" => "playing time"
        }

        @time = choice_param(:time, @times.keys)
        @family = choice_param(:game, @families.keys)
        @sort = choice_param(:sort, @sorts.keys)

        model = PlayerStat.for_period(@time)

        per_page = PGM::Application.config.global_per_page
        page = if @user = username_param and row = model.for_user(@user)
            params.delete(:user)
            1 + (row.ordinal(@sort, @family) - 1) / per_page
        end

        @stats = a_page_of(model.order_by_stat(@sort, @family), page: page, per_page: per_page)

        @users = User.in(player_id: @stats.map(&:id)).index_by(&:player_id)
        @count = (@stats.current_page - 1) * @stats.limit_value + 1

        unless @stats.empty?
            @rank = @stats[0].rank(@sort, @family)
            @value = @stats[0].stat(@sort, @family)
        end
    end

    def teleport
        current_user and current_user.teleport_to(@player)
        redirect_to user_path(@player)
    end

    protected

    def find_user
        unless @player = User.by_username_or_id(params[:name])

            # Redirect from an old username only if it is unambiguous
            users = User.with_past_username(params[:name])
            if users.count == 1
                redirect_to user_path(users.first)
            else
                not_found
            end
        end
    end
end
