/*
 * Requires jquery-ui/sortable
 *
$(document).ready(function () {
    var timer;

    $('#map_selection').sortable({
        update: function(event, ui) {
            setStatus(1);

            var data = "";

            $("#map_selection").find("td").each(function(key, value) {
                map = $(value).attr('map');
                data += "maps[" + key + "]=" + map + "&";
            });

            data.substring(0, data.length - 1);

            clearTimeout(timer);
            timer = setTimeout(function() {
                $.ajax({
                    url: window.location.pathname + "/modify_selection",
                    data: data,
                    method: "POST",
                    success: function() {
                        setStatus(0);
                    },
                    error: function() {
                        setStatus(2);
                    }
                });
            }, 750);
        }
    });
    $('#map_selection').disableSelection();

    function setStatus(status) {
        if(status == 0) {
            $(".status-indicator").addClass("label-success");
            $(".status-indicator").html("Saved");
        } else if(status == 1) {
            $(".status-indicator").addClass("label-warning");
            $(".status-indicator").html("Saving...");
        } else if(status == 2) {
            $(".status-indicator").addClass("label-danger");
            $(".status-indicator").html("Failed");
        }

        if(status == 0 || status == 1) {
            $(".status-indicator").removeClass("label-danger");
        }
        if(status == 1 || status == 2) {
            $(".status-indicator").removeClass("label-success");
        }
        if(status == 2 || status == 0) {
            $(".status-indicator").removeClass("label-warning");
        }
    }
});
*/
