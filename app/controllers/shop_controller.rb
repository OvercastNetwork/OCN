class ShopController < ApplicationController
    before_filter :block_banned_users
    skip_before_filter :html_only, :only => [:status, :purchase]

    def index
        @packages = Package.available.asc_by(&:priority)

        if @gift = model_param(Gift.giveable, :gift, required: false)
            @recipient = @gift.user
            @package = @gift.package
        elsif defaults = session[:shop]
            @recipient = User.find(defaults[:recipient_id])
            @package = Package.available.find_by_attrs(id: defaults[:package_id])
        else
            @recipient = current_user
        end

        if current_user
            begin
                @braintree_client_token = Braintree::ClientToken.generate(customer_id: current_user.id.to_s)
            rescue ArgumentError => ex
                raise unless ex.message =~ /customer/i # Assume this is customer not found
            end
        end

        @braintree_client_token ||= Braintree::ClientToken.generate
    end

    def status
        now = Time.now

        json = {
            sale: !Sale.current.nil?
        }

        if recipient = model_param(User, :recipient_id)
            json[:username] = recipient.username

            if recipient.accepts_purchases_from?
                json[:packages] = Package.purchases_by_id(activated_at: now, recipient: recipient)
            else
                json[:packages] = {}
                json[:message] = "#{recipient.username} does not accept purchases from others"
            end
        else
            json[:username] = nil
            json[:packages] = Package.purchases_by_id(activated_at: now)
        end

        render json: json
    end

    def purchase
        unless user_signed_in?
            return redirect_to({action: 'index'}, flash: {error: "You must be signed in to use the shop"})
        end

        recipient = model_param(User, :recipient_id, required: true)
        package = Package.available.find{|p| p.id.to_s == params[:package_id] } or return not_found
        price = required_param(:price)
        nonce = required_param(:payment_method_nonce)

        session[:shop] = {package_id: package.id, recipient_id: recipient.id}

        transaction = Transaction.new_package_purchase(
            processor: Transaction::Braintree.new(payment_method_nonce: nonce),
            package: package,
            price: price,
            recipient: recipient,
            buyer: current_user,
            ip: request.remote_ip
        )

        if transaction.purchase_valid?
            transaction.process!

            if transaction.success?
                session[:shop] = nil
                return redirect_to({action: 'thanks'}, flash: {transaction_id: transaction.id})
            end

            if transaction.status == Transaction::Status::DECLINED
                error = "Your purchase was declined by the payment provider. Please ensure the payment method is valid."
            else
                Raven.capture_message("Unhandled failure processing transaction #{transaction.id}")
                error = "There was a problem processing your payment. Please email #{ORG::EMAIL}"
            end
        else
            Raven.capture_message("Invalid purchase: #{transaction.note}")
            error = "Your purchase is no longer valid, please try again. If you get this error more than once, please email #{ORG::EMAIL}"
        end

        redirect_to({action: 'index'}, flash: {error: error})
    end

    def thanks
        if tid = flash[:transaction_id]
            @transaction = model_find(Transaction, tid)
        else
            redirect_to shop_path
        end
    end

    private

    def block_banned_users
        redirect_to root_path if current_user_safe.is_in_game_banned?
    end
end
