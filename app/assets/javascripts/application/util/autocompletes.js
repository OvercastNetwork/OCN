$(document).ready(function () {
    $('.typeahead').typeahead({
        source: function(query, process) {
            $.ajax({
                type: "POST",
                url: "/autocomplete/" + JSON.stringify(query).replace(/[^a-zA-Z0-9-_]+/g, ''),
                contentType: "application/json; charset=utf-8",
                dataType: "json",
                success: function (response) {
                    var users = [];
                    if (response) {
                        $(response).each(function (index, val) {
                            users.push(val);
                        });
                        process(users);
                    }
                }
            });
        }
    });

    var name;

    $('#player-search').on('change', function(event) {
        name = event.target.value;
        setTimeout(function redirect() {
            window.location = "/" + name
        }, 200);
    });

    $('#admin-user-search_user').on('change', function(event) {
        setTimeout(function redirect() {
            window.location = "/admin/users/" + event.target.value + "/edit"
        }, 200);
    });

    $("[rel=tooltip]").tooltip();
});
