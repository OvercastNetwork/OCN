$(document).ready(function() {
    $('#action').on('shown.bs.modal', function() {
        $(this).find("textarea:first").focus();
    });

    $(".action").click(function() {
        if($(this).attr("disabled")) return false;
        $("#action-id").attr("value", $(this).data("id"));
    });

    $('#appeals').on('change', function(event) {
        name = event.target.value;
        setTimeout(function redirect() {
            window.location = "/appeals/new/" + name
        }, 200);
    });
});
