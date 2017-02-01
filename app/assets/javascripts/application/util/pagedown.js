$(document).ready(function () {
    // custom help
    var help = {
        handler: function() {
            $("#wmd-help").modal();
            return false;
        },
        title: "Markdown and Emoji Help"
    };

    // setup editor
    var editor = new Markdown.Editor(new Markdown.Converter(), "-text", help);
    editor.run();

    // fix heading icon
    var heading = $('#wmd-heading-button-text i');
    heading.addClass('fa fa-header');
    heading.removeClass('icon-header')

    // fix horizontal rule icon
    var horizontal = $('#wmd-hr-button-text i');
    horizontal.addClass('fa fa-minus');
    horizontal.removeClass('icon-hr-line');

    // hide unnecessary label
    $('label.pagedown.optional').hide();
});
