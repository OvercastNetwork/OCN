$(document).ready(function () {
    $(".mass-moderation").click(function() {
        var elem = $(this).find(':checkbox');
        elem.prop('checked', !elem.is(':checked'));
    });

    $(".mass-moderation input").click(function(){
        var elem = $(this);
        elem.prop('checked', !elem.is(':checked'));
    });

    $(".mass-moderation[rel=popover]").popover({
        placement: 'bottom',
        trigger: 'hover',
        content: popModerationData()
    })
    .hover(function() {
        $('.popover .popover-content').html(popModerationData());
    })
    .click(function() {
        $('.popover .popover-content').html(popModerationData());
    });

    function popModerationData() {
        var num = $(".mass-moderation :checkbox:checked").length;
        return num + " post" + (num == 1 ? "" : "s") + " selected";
    }
});
