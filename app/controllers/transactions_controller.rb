class TransactionsController < ApplicationController
    before_filter :valid_user

    def index
        @transactions = Transaction.where(:user_id => current_user.id, :status.gt => 0)

        params[:page] = [1, params[:page].to_i, (@transactions.count.to_f / PGM::Application.config.global_per_page).ceil].sort[1]

        @transactions = @transactions.desc(:created_at).page(params[:page]).per(PGM::Application.config.global_per_page)
    end
end
