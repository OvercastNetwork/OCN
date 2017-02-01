class ReportsController < ApplicationController
    before_filter :block_in_game_banned_users, :only => [:new, :create, :report]

    def report
        redirect_to reports_path, :alert => 'You do not have permission to create reports.' unless Report.can_create?(current_user)
    end

    def index
        @sort = params[:sort] || 'open'
        return redirect_to_back reports_path, :alert => 'Invalid sort specified.' unless %w(open closed locked escalated all).include?(@sort)

        @reports = Report.web.viewable_by(current_user_safe)

        if params[:reporter] && @reporter = User.by_username(params[:reporter])
            @reports = @reports.reporter(@reporter)
        end
        if params[:reported] && @reported = User.by_username(params[:reported])
            @reports = @reports.reported(@reported)
        end

        unless @reports.nil?
            if @sort == 'open'
                @reports = @reports.opened.asc(:created_at)
            elsif @sort == 'closed'
                @reports = @reports.closed.desc(:updated_at)
            elsif @sort == 'locked'
                @reports = @reports.locked.desc(:updated_at)
            elsif @sort == 'escalated'
                @reports = @reports.escalated.opened.desc(:updated_at)
            elsif @sort == 'all'
                @reports = @reports.desc(:updated_at)
            end

            @reports = a_page_of(@reports)
        end
    end

    def new
        return redirect_to reports_path, :alert => 'You do not have permission to create reports.' unless Report.can_create?(current_user)
        return redirect_to reports_path, :alert => 'No player was specified. Please contact an administrator if this error persists.' if params[:name].nil?
        return redirect_to_back reports_path, :alert => 'Could not find the specified user.' unless @user = User.by_username(params[:name])
        redirect_to_back reports_path, :alert => 'You may not report yourself.' if @user == current_user
    end

    def create
        return redirect_to_back reports_path, :alert => 'You do not have permission to create reports.' unless Report.can_create?(current_user)
        return redirect_to_back reports_path, :alert => 'No player was specified. Please contact an administrator if this error persists.' if params[:user_id].nil?
        return redirect_to_back reports_path, :alert => 'Could not find the specified user.' unless user = User.find(params[:user_id])
        return redirect_to_back reports_path, :alert => 'You may not report yourself.' if user == current_user

        return redirect_to_back report_path, :alert => 'One of the required fields was empty.' if params[:report][:rules].blank? || params[:report][:evidence].blank?

        report = Report.web.create!(reporter: current_user,
                                    reported: user,
                                    reason: params[:report][:rules],
                                    evidence: params[:report][:evidence],
                                    misc_info: params[:report][:misc])

        redirect_to report.can_view?(current_user) ? report_path(report) : reports_path, :alert => 'Thank you. The issue will be dealt with shortly.'
    end

    def show
        return not_found unless @report = Report.find(params[:id])
        return not_found unless @report.can_view?(current_user)

        if Report.can_index?('all', current_user)
            @game_reports = Report.game.reported(@report.reported).desc(:created_at).limit(20)
            @web_reports = Report.web.reported(@report.reported).desc(:updated_at).limit(20)
        end

        @punishments = Punishment.where(punished: @report.reported).desc(:date)
        scope = @same_user ? 'own' : 'all'
        @punishments = @punishments.to_a.select { |x| x.can_index?(current_user) }

        unless @punishments.empty?
            @displayed_statuses = %w(inactive contested automatic stale).select do |status|
                Punishment.can_distinguish_status?(status, scope, current_user)
            end
        end

        @issueable_types = Punishment::Type::ALL.select {|type| @report.can_issue?(type, current_user)}

        @can = {
            :report => {
                :close => @report.can_close?(current_user),
                :open => @report.can_open?(current_user),
                :lock => @report.can_lock?(current_user),
                :unlock => @report.can_unlock?(current_user),
                :escalate => @report.can_escalate?(current_user),
                :comment => @report.can_comment?(current_user)
            }
        }
    end

    def latest
        return not_found unless @report = Report.find(params[:report_id])
        redirect_to report_path(@report) + "#action-#{@report.actions.last.id}"
    end
end
