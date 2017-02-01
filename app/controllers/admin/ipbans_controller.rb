module Admin
    class IpbansController < BaseController
        breadcrumb "IP Bans"

        def self.general_permission
            ['misc', 'ipban', 'edit', true]
        end

        skip_before_filter :authenticate_admin
        before_filter :find_ipban, :only => [:edit, :update, :destroy]

        def index
            @ipbans = Ipban.all
        end

        def new
            @ipban = Ipban.new(:ip => params[:ip], :description => params[:description])
        end

        def edit
        end

        def create
            process_form
            @ipban = Ipban.new(params[:ipban])

            if @ipban.save
                redirect_to admin_ipbans_path, :notice => "IP ban created"
            else
                redirect_to_back new_admin_ipban_path, :alert => "IP ban failed to create"
            end

        rescue Mongo::Error => e
            if e.message =~ /E11000/
                redirect_to_back admin_ipbans_path, :alert => "The specified IP range is already banned"
            else
                redirect_to_back new_admin_ipban_path, :alert => "An error occured creating the IP ban"
            end
        end

        def update
            process_form
            if @ipban.update_attributes(params[:ipban])
                redirect_to admin_ipbans_path, :notice => "IP ban updated"
            else
                redirect_to_back edit_admin_ipban_path(@ipban), :alert => "IP ban failed to update"
            end
        end

        def destroy
            @ipban.destroy
            redirect_to admin_ipbans_path, :notice => "IP ban deleted"
        end

        private
        def process_form
            params[:ipban][:to] = nil if params[:ipban][:to].blank?
            params[:ipban][:mask] = nil if params[:ipban][:mask].blank?
        end

        def find_ipban
            @ipban = model_param(Ipban)
            breadcrumb @ipban.description
        end
    end
end
