$(document).ready(function () {
    var email = null;
    var token = $("#registration #token").data('token');

    for(var i = 1; i < 5; i++) {
        $("#registration a[href=#tab" + i + "]").click(createHandler(i));
    }

    function createHandler(j) {
        return function() {
            email = $("#registration #email").val().replace(/<|>/g, '');
            $("#registration #email-confirm").html(email);

            if(email != null && email.length > 5) {
                // the previous step to hide
                var k = j - 1;

                // if step 3 fails go back to step 1
                if(j == 1) k = 3;

                $("#registration li.tab" + k).toggleClass("disabled");
                $("#registration li.tab" + k).toggleClass("active");
                $("#registration li.tab" + j).toggleClass("disabled");
                $("#registration li.tab" + j).toggleClass("active");
            } else {
                $("#registration #email-invalid").slideDown();
                return false;
            }

            if(j == 3) {
                var ajax = function() {
                    $.post('/register', {token : token, email : email}, function(data) {
                        if(data.success) {
                            clearInterval(interval);
                            $("a[href=#tab4]").click();
                            $("#registration #username").html(data.username);
                        }

                        if(data.email_result != 'available') {
                            clearInterval(interval);
                            $("a[href=#tab1]").click();
                            $("#registration #email-" + data.email_result).slideDown();
                        }
                    });
                };

                ajax();
                var interval = setInterval(ajax, 3000);
            }
        };
    }
});
