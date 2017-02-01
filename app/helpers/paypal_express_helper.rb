module PaypalExpressHelper
    def get_setup_purchase_params(total, request)
        return to_cents(total), {
            :ip => request.remote_ip,
            :return_url => url_for(:action => 'review', :only_path => false),
            :cancel_return_url => home_url,
            :subtotal => to_cents(subtotal),
            :shipping => to_cents(shipping),
            :handling => 0,
            :tax =>      0,
            :allow_note =>  true,
            :items => get_items(cart),
        }
    end

    def to_cents(money)
        (money*100).round
    end
end
