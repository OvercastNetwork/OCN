$(document).ready(function () {
    $(document).on("keypress", ":input:not(textarea)", function(event) {
        return event.keyCode != 13;
    });
    $('#punishment-form').submit(function( event ) {
        event.preventDefault();
        $(".confirm-type").text($('#punishment_type').val());
        $("#confirm-reason").text($('#punishment_reason').val());

        $('#confirm').modal();
    });
    $('#confirm-submit').click(function() {
        $('#punishment-form').off('submit').submit();
    });
});