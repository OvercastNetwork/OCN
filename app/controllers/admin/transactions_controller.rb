module Admin
    class TransactionsController < BaseController
        skip_before_filter :html_only, :only => [:modify]
        before_filter :find_transaction, :except => [:index]

        def index
            @status = int_param(:status)
            @buyer = model_param(User, :buyer_id)
            @recipient = model_param(User, :recipient_id)

            @transactions = Transaction.all
            @transactions = @transactions.buyer(@buyer) if @buyer
            @transactions = @transactions.recipient(@recipient) if @recipient
            @transactions = @transactions.where(status: @status) if @status
            @transactions = a_page_of(@transactions.desc(:updated_at), per_page: 50)
        end

        def show
            @transactions_by = Transaction.buyer(@transaction.user).desc(:updated_at) if @transaction.user
            @transactions_for = Transaction.recipient(@transaction.purchase.recipient).desc(:updated_at) if @transaction.try!(:purchase).try!(:recipient)
        end

        def update
            OCN::MassAssignmentSecurity.without_attr_protection(context: Mongoid::Document) do
                @transaction.update_attributes!(params[:transaction])
            end
            redirect_to_back admin_transaction_path(@transaction)
        end

        def refund
            @transaction.refund!
            redirect_to admin_transaction_path(@transaction), notice: "Transaction refunded"
        rescue Transaction::Error => e
            redirect_to admin_transaction_path(@transaction), flash: {error: e.message}
        end

        def give_package
            @transaction.give_package!
            redirect_to admin_transaction_path(@transaction), notice: "Package given"
        rescue Transaction::Error => e
            redirect_to admin_transaction_path(@transaction), flash: {error: e.message}
        end

        def revoke_package
            @transaction.revoke_package!
            redirect_to admin_transaction_path(@transaction), notice: "Package revoked"
        rescue Transaction::Error => e
            redirect_to admin_transaction_path(@transaction), flash: {error: e.message}
        end

        private

        def find_transaction
            @transaction = model_param(Transaction, required: true)
            breadcrumb @transaction.id.to_s
        end

        def transaction_status_class(trans)
            case trans.status
                when Transaction::Status::PAYED
                    'transaction-payed'
                when Transaction::Status::DECLINED
                    'transaction-declined'
                when Transaction::Status::REFUNDED
                    'transaction-refunded'
                when Transaction::Status::INVALID
                    'transaction-invalid'
            end
        end
        helper_method :transaction_status_class

        def transaction_row_class(trans)
            if trans.fake?
                'warning'
            elsif trans.user && trans.user.shop_lockout_at
                'error'
            end
        end
        helper_method :transaction_row_class
    end
end
