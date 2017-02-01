$(document).ready(function () {
    $(".friend-icon")
    .mouseenter(function () {
        $(this).find(".remove-friend").show();
    })
    .mouseleave(function() {
        $(this).find(".remove-friend").hide();
    });
});
