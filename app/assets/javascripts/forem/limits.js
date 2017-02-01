$(document).ready(function () {
    $(".post_text textarea").on('input selectionchange propertychange', function() {
        var form = $(this).closest('form');
        if($(this).val().length > 30000) {
            form.addClass('has-error');
            form.children('.help-block').show('fast');
            form.children('input[type=submit]').prop('disabled', true)
        } else {
            form.removeClass('has-error');
            form.children('.help-block').hide('fast');
            form.children('input[type=submit]').prop('disabled', false)
        }
    })
});
