module Admin
    class BannersController < BaseController
        breadcrumb "Banners"
        
        def self.general_permission
            ['banner', 'admin', true]
        end

        skip_before_filter :authenticate_admin
        before_filter :find_banner, :only => [:edit, :update, :destroy]

        def index
            @banners = a_page_of(Banner.order_by(active: -1, weight: -1))
        end

        def new
            @banner = Banner.new
        end

        def create
            @banner = Banner.new(parse_params(params))
            if @banner.save
                redirect_to admin_banners_path, :notice => "Banner created"
            else
                render :new, :alert => @banner.errors.full_messages.first
            end
        end

        def edit
        end

        def update
            if @banner.update_attributes(parse_params(params))
                redirect_to admin_banners_path, :notice => "Banner updated"
            else
                render :new, :alert => @banner.errors.full_messages.first
            end
        end

        def destroy
            @banner.destroy
            redirect_to admin_banners_path, :notice => "Banner deleted"
        end
        
        private
        
        def find_banner
            @banner = model_param(Banner)
            breadcrumb @banner.text
        end
        
        def parse_params(params)
            attrs = params[:banner]
            attrs[:expires_at] = parse_time(attrs[:expires_at])
            attrs
        end
        
        def parse_time(text)
            if text.blank?
                Time::INF_FUTURE
            else
                Chronic.parse(text)
            end
        end
        
    end
end
