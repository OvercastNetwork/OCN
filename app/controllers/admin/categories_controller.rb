module Admin
    class CategoriesController < BaseController

        before_filter :find_category, :only => [:edit, :update, :destroy]

        def index
            @category = Forem::Category.all.order_by([:order, :asc])
        end

        def new
            @category = Forem::Category.new
        end

        def create
            @category = Forem::Category.new(params[:category])
            if @category.save
                redirect_to admin_categories_path, :notice => "Category created"
            else
                redirect_to_back new_admin_category_path, :alert => "Category failed to create"
            end
        end

        def edit
        end

        def update
            if @category.update_attributes(params[:category])
                redirect_to_back edit_admin_category_path(@category), :notice => "Category updated"
            else
                redirect_to_back edit_admin_category_path(@category), :alert => "Category failed to update"
            end
        end

        def destroy
            @category.destroy
            redirect_to admin_categories_path, :notice => "Category deleted"
        end

        protected

        def find_category
            @category = model_param(Forem::Category)
            breadcrumb @category.name
        end
    end
end
