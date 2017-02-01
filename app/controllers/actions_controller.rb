class ActionsController < ApplicationController

    def index
        redirect_to_back request.url.gsub("/actions", "")
    end

    def create
        user_signed_in? or go_back alert: "You must be logged in to create an appeal"

        # Verify type sent, verify only one appeal id / report id sent
        if !params[:appeal_id].to_s.blank?
            appeal = true
            id = params[:appeal_id].to_s
            object = Appeal.find(id)
        elsif !params[:report_id].to_s.blank?
            appeal = false
            id = params[:report_id].to_s
            object = Report.find(id)
        end

        return_to(appeals_path)

        object.nil? and go_back alert: "An error occurred in locating the corresponding object for this request"
        object_path = if appeal then appeal_path(id) else report_path(id) end
        return_to(object_path)

        action_class = Action::Base.action_for_token(params[:type]) or go_back alert: "Invalid action"

        action_params = {user: current_user_safe}
        action_params[:comment] = params[:comment] unless params[:comment].blank?

        case params[:type]
            when 'comment'
                raise Permissions::Denied unless object.can_comment?(current_user)
                go_back alert: "Comment may not be left blank" if params[:comment].to_s.blank?
            when 'escalate'
                raise Permissions::Denied unless object.can_escalate?(current_user)[0]
            when 'close'
                raise Permissions::Denied unless object.can_close?(current_user)
            when 'open'
                raise Permissions::Denied unless object.can_open?(current_user)
            when 'lock'
                raise Permissions::Denied unless object.can_lock?(current_user)
            when 'unlock'
                raise Permissions::Denied unless object.can_unlock?(current_user)
            when 'appeal', 'unappeal', 'expire'
                go_back alert: "No punishment specified" if params[:punishment_id].to_s.blank?
                go_back alert: "Punishment specified could not be located" unless punishment = Punishment.find(params[:punishment_id])

                if %w(appeal unappeal).include?(params[:type])
                     go_back alert: "You don't have permission to appeal this punishment" unless punishment.can_edit?('active', current_user)
                    punishment.active = params[:type] != 'appeal'
                elsif params[:type] == 'expire'
                    go_back alert: "You don't have permission to expire this punishment" unless punishment.can_edit?('expire', current_user)
                    go_back alert: "This punishment is not eligible to be expired" unless punishment.expirable?
                    punishment.expire = Time.now
                end
                punishment.save!
                action_params[:punishment] = punishment
            when 'punish'
                go_back alert: "Reason may not be left blank" if params[:data].blank?
                go_back alert: "Reported user not found" unless reported_user = object.reported

                case params[:subtype]
                    when 'game'
                        case params[:title]
                            when 'Warn'
                                type = Punishment::Type::WARN
                                expire = nil
                            when 'Punish'
                                type, expire = Punishment.calculate_next_game(reported_user)
                            when 'Perma'
                                type = Punishment::Type::BAN
                                expire = nil
                        end
                    when 'forum'
                        case params[:title]
                            when 'Warn'
                                type = Punishment::Type::FORUM_WARN
                                expire = nil
                            when '7 Day'
                                type = Punishment::Type::FORUM_BAN
                                expire = 7.days
                            when '30 Day'
                                type = Punishment::Type::FORUM_BAN
                                expire = 30.days
                            when 'Perma'
                                type = Punishment::Type::FORUM_BAN
                                expire = nil
                        end
                    when 'tourney'
                        case params[:title]
                            when 'Ban'
                                type = Punishment::Type::TOURNEY_BAN
                                expire = nil
                        end
                end

                expire = expire.from_now if expire

                go_back alert: "An error occurred in attempting to resolve the specified punishment type" if type.nil?

                raise Permissions::Denied unless object.can_issue?(type, current_user)

                punishment = Punishment.create!(:punished => reported_user,
                                                :punisher => current_user,
                                                :type => type,
                                                :expire => expire,
                                                :reason => params[:data],
                                                :evidence => params[:evidence],
                                                :family => '_web')
                action_params[:punishment] = punishment
            else
                go_back alert: "Invalid type specified"
        end

        action = object.actions.create!(action_params, action_class)
        redirect_to "#{object_path}#action-#{action.id}"

    rescue Permissions::Denied
        go_back alert: "You don't have permission"
    end
end
