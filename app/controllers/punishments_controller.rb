class PunishmentsController < ApplicationController
    layout "application"

    def index
        query = Punishment.all

        unless params[:punisher].blank?
            punisher = User.by_username_or_id(params[:punisher]) or return redirect_to_back punishments_path, :alert => "Could not locate user."
            if Punishment.can_sort?('punisher', 'all', current_user) || (current_user && punisher == current_user && Punishment.can_sort?('punisher', 'own', current_user))
                query = Punishment.where(:punisher => punisher)
                @punisher = punisher
            else
                redirect_to_back punishments_path, :alert => "You do not have permission to sort by #{punisher.username}'s punishments."
            end
        end

        @punishments = query.desc(:date)

        params[:page] = [1, current_page, (@punishments.count.to_f / PGM::Application.config.global_per_page).ceil].sort[1]

        @punishments = @punishments.page(params[:page]).per(PGM::Application.config.global_per_page)

        @displayed_statuses = %w()
        %w(inactive contested automatic stale).each do |status|
            @displayed_statuses << status if Punishment.can_distinguish_status?(status, 'all', current_user)
        end
    end

    def show
        return not_found unless @punishment = Punishment.find(params[:id])
        return not_found unless @punishment.can_view?(current_user)

        @server = @punishment.server
        @can = {
            :punishment => {
                :edit_any => @punishment.can_edit_any?(current_user),
                :appeal => @punishment.active? && is_same_user?(@punishment.punished),
                :view_evidence => @punishment.can_view_evidence?(current_user),
                :view_appeal => @punishment.appealed? && (is_same_user?(@punishment.punished) || Appeal.can_view?('all', current_user))
            }
        }
    end

    def new
        return redirect_to_back punishments_path, :alert => 'You do not have permission to issue punishments directly.' unless Punishment.can_manage?(current_user)
        return redirect_to punishments_path, :alert => 'No player was specified. Please contact an administrator if this error persists.' if params[:name].nil?
        return redirect_to_back punishments_path, :alert => 'Could not find the specified user.' unless @punished = User.by_username(params[:name])
        return redirect_to_back punishments_path, :alert => 'You may not punish yourself.' if @punished == current_user

        @issueable_types = []
        @issueable_types << 'Warn' if Punishment::can_issue?(Punishment::Type::WARN, current_user)
        @issueable_types << 'Kick' if Punishment::can_issue?(Punishment::Type::KICK, current_user)
        @issueable_types << '7 day ban' if Punishment::can_issue?(Punishment::Type::BAN, current_user)
        @issueable_types << 'Permanent ban' if Punishment::can_issue?(Punishment::Type::BAN, current_user)
        @issueable_types << 'Forum warn' if Punishment::can_issue?(Punishment::Type::FORUM_WARN, current_user)
        @issueable_types << '7 day forum ban' if Punishment::can_issue?(Punishment::Type::FORUM_BAN, current_user)
        @issueable_types << '30 day forum ban' if Punishment::can_issue?(Punishment::Type::FORUM_BAN, current_user)
        @issueable_types << 'Permanent forum ban' if Punishment::can_issue?(Punishment::Type::FORUM_BAN, current_user)
        @issueable_types << 'Tourney ban' if Punishment::can_issue?(Punishment::Type::TOURNEY_BAN, current_user)

        @punishment = Punishment.new

        if params[:from_post] && Punishment::can_issue_forum?(current_user)
            @punishment.evidence = forem.post_path(params[:from_post])
            @punishment.type = 'Forum warn'
        end
    end

    def create
        return redirect_to_back punishments_path, :alert => 'Could not find the specified user.' unless punished = User.by_player_id(params[:user_id])

        case params[:punishment][:type]
            when 'Warn'
                type = Punishment::Type::WARN
                expire = nil
            when 'Kick'
                type = Punishment::Type::KICK
                expire = nil
            when '7 day ban'
                type = Punishment::Type::BAN
                expire = 7.days.from_now
            when 'Permanent ban'
                type = Punishment::Type::BAN
                expire = nil
            when 'Forum warn'
                type = Punishment::Type::FORUM_WARN
                expire = nil
            when '7 day forum ban'
                type = Punishment::Type::FORUM_BAN
                expire = 7.days.from_now
            when '30 day forum ban'
                type = Punishment::Type::FORUM_BAN
                expire = 30.days.from_now
            when 'Permanent forum ban'
                type = Punishment::Type::FORUM_BAN
                expire = nil
            when 'Tourney ban'
                type = Punishment::Type::TOURNEY_BAN
                expire = nil
        end

        return redirect_to_back alert: "An error occurred in attempting to resolve the specified punishment type" if type.nil?
        raise Permissions::Denied unless Punishment::can_issue?(type, current_user)

        punishment = Punishment.new(:punished => punished,
                                    :punisher => current_user,
                                    :type => type,
                                    :expire => expire,
                                    :reason => params[:punishment][:reason],
                                    :evidence => params[:punishment][:evidence],
                                    :family => '_web',
                                    :playing_time_ms => punished.stats.playing_time_ms)

        if punishment.save!
            redirect_to punishment_path(punishment), :notice => "Punishment issued"
        else
            redirect_to_back punishments_path, :alert => "Punishment could not be issued"
        end
    end

    def edit
        return not_found unless @punishment = Punishment.find(params[:id])

        @editable = []
        Punishment.accessible_attributes.each do |field|
            @editable << field.to_sym if @punishment.can_edit?(field, current_user)
        end

        @expire_text = (@punishment.expire.nil? ? "never" : @punishment.expire).to_s

        @can_delete = @punishment.can_delete?(current_user)

        return redirect_to_back punishment_path(@punishment), :alert => 'You do not have permission to edit this punishment.' unless @can_delete || !@editable.empty?

        if @editable.include?(:expire)
            @expires = Hash.new
            @punishment.expire = Time.at(0) if @punishment.expire == nil

            @days_total = (@punishment.expire - @punishment.date).in_days.to_i
            @days_left = (@punishment.expire - Time.now).in_days.to_i

            @expires.merge!({"Never - Permanent ban" => nil})

            60.downto(-60) do |n|
                @expires.merge!({n.to_s + " day" + (n == 1 ? "" : "s") + " from now - " + (n - @days_left + @days_total).to_s + " day ban" => @punishment.expire - (@days_left - n).days})
            end
        end

        if @editable.include?(:type)
            @issueable_types = Punishment::Type::ALL.select {|type| Punishment.can_issue?(type, current_user) }
            @editable.delete(:type) if @issueable_types.empty?
        end
    end

    def update
        return redirect_to_back punishments_path, :alert => 'Punishment not found.' unless @punishment = Punishment.find(params[:id])

        if params[:punishment]
            params[:punishment].keys.each do |field|
                return redirect_to_back edit_punishment_path(@punishment), :alert => "You do not have permission to edit the '#{field.to_s}' value of this punishment." unless @punishment.can_edit?(field.to_s, current_user)
            end
        else
            return redirect_to_back edit_punishment_path(@punishment), :alert => 'No changes were specified.'
        end

        if punished_id = params[:punishment].delete(:punished)
            return redirect_to_back edit_punishment_path(@punishment), :alert => "Punishment must have a victim" unless @punishment.punished = User.find(punished_id)
        end

        if punisher_id = params[:punishment].delete(:punisher)
            @punishment.punisher = User.find(punisher_id)
        end

        params[:punishment][:expire] = parse_expire(params[:punishment][:expire])

        unless params[:punishment][:type].nil?
            return redirect_to_back edit_punishment_path(@punishment), :alert => "Invalid punishment type: '#{params[:punishment][:type]}'" unless Punishment::Type::ALL.include? params[:punishment][:type]
        end

        [:active, :automatic, :debatable, :appealed].each do |bool|
            unless params[:punishment][bool].nil?
                params[:punishment][bool] = to_boolean(params[:punishment][bool])
            end
        end

        @punishment.update_attributes(params[:punishment])
        if @punishment.save
            redirect_to_back edit_punishment_path(@punishment), :alert => 'Punishment successfully updated.'
        else
            redirect_to_back edit_punishment_path(@punishment), :alert => 'Punishment failed to update. Please try again, or contact an administrator if this error persists.'
        end
    end

    def parse_expire(text)
        if text.blank?
            nil
        else
            Chronic.parse(text)
        end
    end

    def destroy
        return redirect_to_back punishments_path, :alert => 'Punishment not found.' unless @punishment = Punishment.find(params[:id])

        if @punishment.can_delete?(current_user)
            if @punishment.destroy
                redirect_to punishments_path, :alert => 'Punishment deleted.'
            else
                redirect_to_back punishment_path(@punishment), :alert => 'Punishment failed to delete.'
            end
        else
            redirect_to_back punishment_path(@punishment), :alert => 'You do not have permission to delete this punishment.'
        end
    end
end
