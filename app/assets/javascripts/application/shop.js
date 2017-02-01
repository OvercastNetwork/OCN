function packageElement(packageId) {
    return $('.package-select[data-package-id=' + packageId + ']');
}

function selectPackage(packageId) {
    console.log("Selecting package " + packageId);

    var el = packageElement(packageId);
    if(!el.hasClass('disabled')) {
        $('.package-select').removeClass('selected');
        el.addClass('selected');
        updateForm();
    }
}

function updateForm() {
    var elBuyButton = $('.buy-button');
    var elSelected = $('.package-select.selected');

    if(window.userSearchWidget.value && elSelected.length == 1) {
        elBuyButton[0].disabled = false;
        elBuyButton.removeClass('disabled');

        $('#package-field').val(elSelected.data('package-id'));
        $('#price-field').val(elSelected.data('price'));
    } else {
        elBuyButton[0].disabled = true;
        elBuyButton.addClass('disabled');

        $('#package-field').val('');
        $('#price-field').val('');
    }
}

function updatePackages() {
    var recipientId = window.userSearchWidget.value;
    console.log("Refreshing packages for user " + recipientId);

    var params = {};
    if(recipientId) params.recipient_id = recipientId;

    $.ajax({
        data: params,
        type: 'POST',
        url: '/shop/status',
        error: function(a, b, c) {
            console.log(a);
            console.log(b);
            console.log(c);
        },
        success: function(response) {
            console.log(response);

            $('.user-search-error').html(response.message || "");

            $('.package-select').each(function() {
                var el = $(this);

                var packageId = el.data('package-id');
                var pkg = response.packages[packageId];

                var available = !!pkg || !recipientId;
                el.toggleClass('available', available);
                el.toggleClass('disabled', !available);
                if(!available) el.removeClass('selected');
                el.toggleClass('discounted', response.sale);


                if(pkg) {
                    el.data('price', pkg.price);
                    $('.time', el).html(pkg.time_text);
                    $('.regular .price', el).html(pkg.regular_price_text);
                    $('.discount', el).html(pkg.discount_text);
                    $('.sale .price', el).html(pkg.price_text);
                }
            });

            updateForm();
        }
    });
}

$(document).ready(function() {
    if(window.braintree) {
        braintree.setup(window.braintreeClientToken, "dropin", {
            container: "payment-container",
            form: "shop-form",
            paypal: {
                singleUse: true
            }
        });

        window.userSearchWidget = $('#_recipient_id')[0];
        window.userSearchWidget.onchange = updatePackages;

        $('.package-select').click(function(e) {
            selectPackage($(e.currentTarget).data('package-id'));
        });

        updatePackages();
    }
});
