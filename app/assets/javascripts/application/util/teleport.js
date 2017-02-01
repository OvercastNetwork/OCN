$(document).ready(function () {
    $(".tp-button").click(function(ev) {
        ev.preventDefault();
        $.ajax({url: $(this).attr('href')});
    });
});
