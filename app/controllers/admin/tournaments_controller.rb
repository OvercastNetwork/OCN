module Admin
    class TournamentsController < BaseController
        def self.general_permission
            ['tournament', 'admin', true]
        end

        skip_before_filter :authenticate_admin
        before_filter :check_perms
        before_filter :find_tournament, :only => [:edit, :update]
        before_filter :parse_form, :only => [:create, :update]

        def index
            @tournaments = Tournament.desc(:end)
        end

        def new
            @tournament = Tournament.new
        end

        def create
            @tournament = Tournament.new(params[:tournament])
            if @tournament.save
                redirect_to admin_tournaments_path, :notice => "Tournament created"
            else
                render :new, :alert => "Tournament failed to create"
            end
        end

        def edit
        end

        def update
            if @tournament.update_attributes(params[:tournament])
                redirect_to_back edit_admin_tournament_path(@tournament), :notice => "Tournament updated"
            else
                render :edit, :alert => "Tournament failed to update"
            end
        end

        protected

        def check_perms
            return not_found unless current_user_safe.has_permission?('tournament', 'manage', true)
        end

        def find_tournament
            @tournament = model_param(Tournament)
            breadcrumb @tournament.name
        end

        def parse_form
            form = params[:tournament]
            [:end, :registration_start, :registration_end].each do |field|
                if form[field].blank?
                    form[field] = nil
                else
                    form[field] = Chronic.parse(form[field])
                end
            end
        end

        def format_time_field(t)
            t.utc.to_s if t
        end
        helper_method :format_time_field
    end
end
