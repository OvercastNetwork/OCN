$(document).ready(function () {
    $('#user-tabs').tabCollapse({
        tabsClass: 'hidden-sm hidden-xs',
        accordionClass: 'visible-sm visible-xs'
    });

    $("#user-tabs-accordion").on("shown.bs.collapse", function () {
        var clickedHeader = $(this).find('.panel > .collapse.in').closest('.panel').find('.panel-heading');
        var offset = clickedHeader.offset();
        var top = $(window).scrollTop();
        if(offset) {
            var topOfHeader = offset.top;
            if(topOfHeader < top) {
                $('html,body').animate({ scrollTop: topOfHeader}, 100, 'swing');
            }
        }
    });

    var url = document.location.toString();
    if (url.match('#')) {
        $('.nav-tabs a[href=#'+url.split('#')[1]+']').tab('show') ;
    }
});
