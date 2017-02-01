module Forem
    class CategoriesController < Forem::ApplicationController
        def show
            return not_found unless @category = Forem::Category.find(params[:id])
            return not_found unless @category.can_view?(current_user)
        end
    end
end
