$(document).ready(function () {
    $('.stream').each(function() {
        var options = {
            width: 620,
            height: 450,
            channel: this.id,
        };
        var player = new Twitch.Player(this.id, options);
        player.setVolume(0.5);
    });

    $('#hide-all-streams').on('click', function () {
        $('.stream').each(function(i) {
            $(this).collapse();
        });
    });

    $('.stream').on('hidden', function() {
        var el = $(this).find('object');
        var stream = $(this).attr('id');
        var type = $(this).attr('type');

        el.attr('type', 'invalid');
        $('a[data-stream=' + stream + ']').html(type == 'twitch' ? 'Show ' + stream + "'s stream" : 'Show');
    });

    $('.stream').on('shown', function() {
        var el = $(this).find('object');
        var stream = $(this).attr('id');
        var type = $(this).attr('type');

        el.attr('type', 'application/x-shockwave-flash');
        $('a[data-stream=' + stream + ']').html(type == 'twitch' ? 'Hide ' + stream + "'s stream" : 'Hide');
    });

    $('#refresh').click(function() {
        var stream = $(this).attr('stream');
        var $img = $('img[stream=' + stream + ']');

        $img.attr('src', $img.attr('url') + '&_t=' + (+(new Date())));
    });
});
