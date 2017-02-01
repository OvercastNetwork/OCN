class RulesController < ApplicationController
    def index
        to_code
    end

    def show
        @code = params[:id][0..1]

        if File.exists?(path(@code))
            if params[:id] != @code
                to_code(@code)
            else
                render "rules/#{@code}"
            end
        else
            to_code
        end
    end

    def new
      to_code
    end

    private
    def path(code)
        Rails.root.join('app', 'views', 'rules', "#{code}.haml")
    end

    def to_code(code = "en")
        redirect_to rules_path + '/' + code
    end
end
