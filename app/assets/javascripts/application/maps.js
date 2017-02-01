$(document).ready(function () {
    $(".map-data[rel=popover]").popover({
        placement: 'bottom',
        trigger: 'hover',
        content: ""
    })
    .mouseenter(function() {
        var content = $(this).parent().find('.popover .popover-content');

        content.html('<span class="label label-info">Kills:</span> <span class="data-kills"></span><br>');
        content.append('<span class="label label-info">Deaths:</span> <span class="data-deaths"></span><br>');
        content.append('<span class="label label-info">Teamkills:</span> <span class="data-teamkills"></span><br>');
        content.append('<span class="label label-info">Times played:</span> <span class="data-plays"></span><br>');
        content.append('<span class="label label-info">Average Match:</span> <span class="data-average"></span><br>');
        content.append('<span class="label label-info">Longest Match:</span> <span class="data-longest"></span><br>');
        content.append('<span class="label label-info">Shortest Match:</span> <span class="data-shortest"></span><br>');

        $.getJSON('/maps/stats/' + $(this).data('map'), function(data) {
            $.each(data, function(key, val) {
                content.find('.data-' + key).html(val);
            });
        });
    });

    $(".map-info[rel=popover]").popover({
        placement: 'bottom',
        trigger: 'hover',
        content: ""
    })
    .mouseenter(function() {
        var content = $(this).parent().find('.popover .popover-content');

        content.html('<span class="label label-info">Name:</span> <small class="data-name"></small><br>');
        content.append('<span class="label label-info">Version:</span> <small class="data-version"></small><br>');
        content.append('<span class="label label-info">Made by:</span> <small class="data-authors"></small><br>');
        content.append('<span class="label label-info">Objective:</span> <small class="data-objective"></small><br>');
        content.append('<span class="label label-info">Teams:</span> <small class="data-teams"></small><br>');

        $.getJSON('/maps/info/' + $(this).data('map'), function(data) {
            $.each(data, function(key, val) {
                content.find('.data-' + key).html(val);
            });
        });
    });

    if(window.location.hash != "") {
        var hr = $(window.location.hash + "").prev();

        if(hr.is("hr")) {
            hr.css("outline", "0");
            hr.css("outline", "thin dotted \9");
            hr.css("border-color", "rgba(82, 168, 236, 0.8)");
            hr.css("-webkit-box-shadow", "inset 0 1px 1px rgba(0, 0, 0, 0.075), 0 0 8px rgba(82, 168, 236, 0.6)");
            hr.css("   -moz-box-shadow", "inset 0 1px 1px rgba(0, 0, 0, 0.075), 0 0 8px rgba(82, 168, 236, 0.6)");
            hr.css("        box-shadow", "inset 0 1px 1px rgba(0, 0, 0, 0.075), 0 0 8px rgba(82, 168, 236, 0.6)");
        }
    }
});
