class Report
    include Mongoid::Document
    include Mongoid::Timestamps
    include BackgroundIndexes
    include ActionView::Helpers::DateHelper
    store_in :database => "oc_reports"

    include ApiModel
    include ApiSearchable
    include ApiAnnounceable

    include Subscribable
    include Actionable
    include Closeable
    include Lockable
    include Escalatable

    class Alert < Subscription::Alert
        alias_method :report, :subscribable

        def link
            Rails.application.routes.url_helpers.report_latest_path(report)
        end

        def rich_message
            if report.reporter == user
                [{message: "Your report has been updated by a staff member", time: true}]
            else
                [{user: report.reporter, message: "'s report requires your attention", time: true}]
            end
        end
    end

    field :scope
    validates_inclusion_of :scope, in: ['game', 'web']
    scope :game, where(scope: 'game')
    scope :web, where(scope: 'web')
    index({scope: 1})

    # Fields shared by in-game and website
    field :reason, type: String

    belongs_to :reporter, class_name: 'User', index: true
    field_scope :reporter
    alias_method :actionable_creator, :reporter

    belongs_to :reported, class_name: 'User', index: true
    field_scope :reported
    validates_presence_of :reported

    # Fields used only for in-game reports
    field :family, type: String # TODO: belongs_to :family
    field :automatic, type: Boolean, default: false
    field :staff_online, type: Array # List of staff player_id

    belongs_to :server, index: true
    belongs_to :match, index: true

    # Fields used only for website reports
    field :evidence, type: String
    field :misc_info, type: String

    index(INDEX_created_at = {created_at: 1})
    index(INDEX_updated_at = {updated_at: 1})
    index(INDEX_server = {server_id: 1, created_at: -1})
    index(INDEX_family = {family: 1, created_at: -1})
    index(INDEX_reporter_updated_at = {reporter_id: 1, updated_at: -1})
    index(INDEX_reported_updated_at = {reported_id: 1, updated_at: -1})
    index(INDEX_reported_created_at = {reported_id: 1, created_at: -1})

    props = [:server_id, :match_id, :family, :scope, :reason, :automatic, :staff_online]

    attr_accessible :_id, # Plugins generate the ID
                    :server, :match,
                    :reporter, :reporter_id, :reported, :reported_id,
                    :evidence, :misc_info,
                    *props

    api_property :created_at, :updated_at, *props

    api_synthetic :reporter do
        reporter.api_player_id if reporter
    end

    api_synthetic :reported do
        reported.api_player_id if reported
    end

    action Action::Punish do
        self.open = false
    end

    after_create do
        if Rails.env.production?
            Mattermost::OCN::Report.new(self).post
        end
    end

    class << self
        def viewable_by(user)
            if can_index?('all', user)
                all
            elsif can_index?('own', user)
                # Cannot use `where` here, or a later `where` may overwrite it
                all_of(reporter: user).hint(INDEX_reporter_updated_at)
            else
                all.none
            end
        end

        def reporter_viewable_by(reporter, viewer = User.current)
            if can_index?('all', viewer) || (reporter == viewer && can_index?('own', viewer))
                reporter(reporter).desc(:updated_at).hint(INDEX_reporter_updated_at)
            else
                none
            end
        end

        def reported_viewable_by(reported, viewer = User.current)
            if can_index?('all', viewer)
                reported(reported).desc(:updated_at).hint(INDEX_reported_updated_at)
            else
                none
            end
        end

        def search_request_class
            ReportSearchRequest
        end

        def search_results(request: nil, documents: nil)
            documents = super
            hint = INDEX_created_at

            if request
                if request.server_id
                    documents = documents.where(server_id: request.server_id)
                    hint = INDEX_server
                elsif request.family_ids
                    documents = documents.in(family: request.family_ids)
                    hint = INDEX_family
                end

                if request.user_id
                    documents = documents.reported(User.need(request.user_id))
                    hint = INDEX_reported_created_at
                end
            end

            documents.desc(:created_at).hint(hint)
        end
    end

    def game?
        scope == 'game'
    end

    def web?
        scope == 'web'
    end

    def generate_create_action?
        web?
    end

    def status
        if locked?
            "Locked"
        elsif closed?
            "Closed"
        elsif escalated?
            "Escalated"
        elsif open?
            "Open"
        end
    end

    def color
        if locked?
            "danger"
        elsif closed?
            "success"
        elsif escalated?
            "warning"
        elsif open?
            "info"
        end
    end

    # begin game

    def match_full
        if self.match.nil?
            if self.server?
                self.match = Match.where(:server => self.server, :start.lte => self.date, :end.gte => self.date).first
                self.save
            end
        end

        self.match
    end

    # end game

    def self.can_manage?(user = nil)
        return user && (user.admin? || user.has_permission?('report', 'manage', true))
    end

    def self.can_create?(user = nil)
        return user && (Report.can_manage?(user) || user.has_permission?('report', 'create', true))
    end

    def can_view?(user = nil)
        user ||= User.anonymous_user
        if Report.can_manage?(user)
            return true
        else
            scope = user == self.reporter ? 'own' : 'all'
            return user.has_permission?('report', 'view', scope) || (scope == 'own' && user.has_permission?('report', 'view', 'all'))
        end
    end

    def self.can_index?(scope, user = nil)
        user ||= User.anonymous_user
        Report.can_manage?(user) ||
            user.has_permission?('report', 'index', scope) ||
            (scope == 'own' && user.has_permission?('report', 'index', 'all'))
    end

    def can_comment?(user = nil)
        if user
            if Report.can_manage?(user)
                return true
            else
                scope = user == self.reporter ? 'own' : 'all'
                result = user.has_permission?('report', 'comment', scope) || (scope == 'own' && user.has_permission?('report', 'comment', 'all'))
                result = result && Report.can_action_on_closed?(scope, 'comment', user) if self.closed?
                result = result && Report.can_action_on_locked?(scope, 'comment', user) if self.locked?
                result = result && Report.can_action_on_escalated?(scope, 'comment', user) if self.escalated?
                return result
            end
        end
    end

    def can_close?(user = nil)
        return false if self.closed?
        if user
            if Report.can_manage?(user)
                return true
            else
                scope = user == self.reporter ? 'own' : 'all'
                result = user.has_permission?('report', 'close', scope) || (scope == 'own' && user.has_permission?('report', 'close', 'all'))
                result = result && Report.can_action_on_locked?(scope, 'close', user) if self.locked?
                result = result && Report.can_action_on_escalated?(scope, 'close', user) if self.escalated?
                return result
            end
        end
    end

    def can_open?(user = nil)
        return false if self.open?
        if user
            if Report.can_manage?(user)
                return true
            else
                scope = user == self.reporter ? 'own' : 'all'
                result = user.has_permission?('report', 'open', scope) || (scope == 'own' && user.has_permission?('report', 'open', 'all'))
                result = result && Report.can_action_on_closed?(scope, 'open', user) if self.closed?
                result = result && Report.can_action_on_locked?(scope, 'open', user) if self.locked?
                result = result && Report.can_action_on_escalated?(scope, 'open', user) if self.escalated?
                return result
            end
        end
    end

    def can_lock?(user = nil)
        return false if self.locked?
        if user
            if Report.can_manage?(user)
                return true
            else
                scope = user == self.reporter ? 'own' : 'all'
                result = user.has_permission?('report', 'lock', scope) || (scope == 'own' && user.has_permission?('report', 'lock', 'all'))
                result = result && Report.can_action_on_closed?(scope, 'lock', user) if self.closed?
                result = result && Report.can_action_on_escalated?(scope, 'lock', user) if self.escalated?
                return result
            end
        end
    end

    def can_unlock?(user = nil)
        return false unless self.locked?
        if user
            if Report.can_manage?(user)
                return true
            else
                scope = user == self.reporter ? 'own' : 'all'
                result = user.has_permission?('report', 'unlock', scope) || (scope == 'own' && user.has_permission?('report', 'unlock', 'all'))
                result = result && Report.can_action_on_closed?(scope, 'unlock', user) if self.closed?
                result = result && Report.can_action_on_locked?(scope, 'unlock', user) if self.locked?
                result = result && Report.can_action_on_escalated?(scope, 'unlock', user) if self.escalated?
                return result
            end
        end
    end

    def can_escalate?(user = nil)
        return [false] if self.escalated?
        time = (created_at.to_i < 24.hours.ago.to_i || self.closed?) ? 'delayed' : 'immediately'
        if user
            if Report.can_manage?(user)
                return [true]
            else
                msg = nil
                scope = user == self.reporter ? 'own' : 'all'
                result = user.has_permission?('report', 'escalate', time, scope) || (scope == 'own' && user.has_permission?('report', 'escalate', time, 'all'))
                result = result || user.has_permission?('report', 'escalate', 'immediately', scope) || (scope == 'own' && user.has_permission?('report', 'escalate', 'immediately', 'all')) if time == 'delayed'
                msg = "You must wait #{time_ago_in_words(self.created_at - 24.hours)} to escalate this report." if !result && time == 'immediately' && (user.has_permission?('report', 'escalate', 'delayed', scope) || (scope == 'own' && user.has_permission?('appeal', 'escalate', 'delayed', 'all')))
                if self.closed? && !Report.can_action_on_closed?(scope, 'escalate')
                    result = false
                    msg = nil
                end
                if self.locked? && !Report.can_action_on_locked?(scope, 'escalate')
                    result = false
                    msg = nil
                end
                return [result, result ? 'This will delay response times.' : msg]
            end
        end
    end

    def can_issue?(type, user = nil)
        if user
            if Report.can_manage?(user)
                return true
            else
                scope = user == self.reporter ? 'own' : 'all'
                result = Punishment.can_issue?(type, user)
                result = result && Report.can_action_on_closed?(scope, 'punish', user) if self.closed?
                result = result && Report.can_action_on_locked?(scope, 'punish', user) if self.locked?
                result = result && Report.can_action_on_escalated?(scope, 'punish', user) if self.escalated?
                result
            end
        end
    end

    def self.can_action_on_closed?(scope, action, user = nil)
        return user && (user.has_permission?('report', 'action_on_closed', action, scope) || (scope == 'own' && user.has_permission?('report', 'action_on_closed', action, 'all')))
    end

    def self.can_action_on_locked?(scope, action, user = nil)
        return user && (user.has_permission?('report', 'action_on_locked', action, scope) || (scope == 'own' && user.has_permission?('report', 'action_on_locked', action, 'all')))
    end

    def self.can_action_on_escalated?(scope, action, user = nil)
        user ||= User.anonymous_user
        Report.can_manage?(user) ||
            user.has_permission?('report', 'action_on_escalated', action, scope) ||
            (scope == 'own' && user.has_permission?('report', 'action_on_escalated', action, 'all'))
    end
end
