$(document).ready(function () {
    $('#reports').on('change', function(event) {
        name = event.target.value;
        setTimeout(function redirect() {
            window.location = "/reports/new/" + name
        }, 200);
    });
});
