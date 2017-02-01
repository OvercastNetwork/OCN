$(document).ready(function () {
    $('a.dropdown-toggle, .dropdown-menu a').on('touchstart', function(e) {
        e.stopPropagation();
    });
});
