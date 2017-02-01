class AppealsController < ApplicationController
    before_filter :valid_user, :except => [:appeal]

    def appeal
        @can_appeal = user_signed_in? && (Punishment.punished(current_user).unappealed.exists? ||
                                          Appeal.punished(current_user).exists?)
    end

    def index
        @sort = params[:sort] || 'open'
        @valid_sorts = %w(all open closed locked escalated)
        @valid_sorts << 'own' if user_signed_in? && Appeal.can_index?('all', current_user)
        return redirect_to_back appeals_path, :alert => 'Invalid sort specified.' unless @valid_sorts.include?(@sort)

        @appeals = Appeal.indexable_by(current_user_safe)

        if params[:punisher] && @punisher = User.by_username_or_id(params[:punisher])
            @appeals = @appeals.punisher(@punisher)
        end

        unless @appeals.nil?
            if @sort == 'open'
                @appeals = @appeals.where(:open => true)
            elsif @sort == 'closed'
                @appeals = @appeals.where(:open => false)
            elsif @sort == 'locked'
                @appeals = @appeals.where(:locked => true)
            elsif @sort == 'escalated'
                @appeals = @appeals.where(:escalated => true, :open => true)
            elsif @sort == 'own'
                @appeals = @appeals.punisher(current_user)
            end

            @appeals = a_page_of(@appeals.by_updated_at)
        end
    end

    def new
        @punishments = Punishment.desc(:date).punished(current_user).appealable
        types = []
        Punishment::Type::ALL.each do |type|
            types << type if Punishment.can_index?(['type', type], 'own', current_user)
        end
        @punishments = !types.empty? ? @punishments.where(:type => {'$in' => types}) : nil
        return redirect_to_back appeals_path, :alert => 'You do not have permission to view any of your punishments which are eligible for appeal.' if @punishments.nil?

        @appeals = Appeal.can_index?('own', current_user) ? Appeal.punished(current_user).desc(:updated_at) : nil

        redirect_to_back appeals_path, :alert => 'You do not have any punishments eligible for appeal (or any existing appeals).' if @punishments.count == 0 && (@appeals.nil? || @appeals.count == 0)
    end

    def create
        return redirect_to_back appeals_path, :alert => 'An explanation was not given.' if params[:explanation].blank?

        appeal = Appeal.new(punished: current_user, authorized_ip: request.remote_ip)

        if punishment = Punishment.appealable_by.find(params[:punishment])
            appeal.add_excuse(punishment, params[:explanation])
        end

        return redirect_to_back appeals_path, :alert => 'No punishments were selected to appeal.' if appeal.excuses.empty?

        if appeal.save
            redirect_to appeal_path(appeal), :alert => 'Bookmark this page! It will provide updates.'
        else
            redirect_to_back appeals_path, :alert => "There was a problem creating your appeal. Please contact #{ORG::EMAIL}"
        end
    end

    def show
        return not_found unless @appeal = Appeal.find(params[:id])
        return not_found unless @appeal.can_view?(current_user)

        @same_user = @appeal.same_user?(current_user)

        if user_signed_in?
            @appeal.mark_read!(by: current_user)
            if @appeal.can_view_ip?(current_user)
                session = Session.last_started_by(@appeal.punished)
                @session_ip = session == nil ? 'Unknown' : session.ip
            end
        end

        if Report.can_index?('all', current_user)
            @game_reports = Report.game.reported(@appeal.punished).desc(:created_at).limit(20)
            @web_reports = Report.web.reported(@appeal.punished).desc(:updated_at).limit(20)
        end

        @can = {
            :appeal => {
                :close => @appeal.can_close?(current_user),
                :open => @appeal.can_open?(current_user),
                :lock => @appeal.can_lock?(current_user),
                :unlock => @appeal.can_unlock?(current_user),
                :escalate => @appeal.can_escalate?(current_user),
                :comment => @appeal.can_comment?(current_user),
                :view_ip => @appeal.can_view_ip?(current_user)
            },
            :punishments => {}
        }
        @punishments = @appeal.excuses.map(&:punishment)
        @punishments.each do |punishment|
            appeal_or_unappeal = punishment.can_edit?('active', current_user)

            appeal = appeal_or_unappeal && @appeal.can_appeal?(current_user_safe)
            @can[:punishments][punishment.id.to_s] = {:appeal => appeal}
            @can[:appeal][:appeal] = appeal

            unappeal = appeal_or_unappeal && @appeal.can_unappeal?(current_user_safe)
            @can[:punishments][punishment.id.to_s].merge!({:unappeal => unappeal})
            @can[:appeal][:unappeal] = unappeal

            expire = punishment.expirable? && punishment.can_edit?('expire', current_user)
            expire &= @appeal.can_expire?(current_user_safe)
            @can[:punishments][punishment.id.to_s].merge!({:expire => expire})
            @can[:appeal][:expire] = true if expire
        end
    end

    def latest
        return not_found unless @appeal = Appeal.find(params[:appeal_id])
        return not_found unless @appeal.can_view?(current_user)
        if last = @appeal.actions.last
            redirect_to "#{appeal_path(@appeal)}#action-#{last.id}"
        else
            redirect_to appeal_path(@appeal)
        end
    end
end
