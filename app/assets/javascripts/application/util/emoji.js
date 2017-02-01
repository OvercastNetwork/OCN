$(document).ready(function () {
    $('.emojify').textcomplete([
        { // emoji strategy
            match: /\B:([\-+\w]*)$/,
            search: function (term, callback) {
                callback($.map(emojis_names, function (emoji) {
                    return emoji.indexOf(term) === 0 ? emoji : null;
                }));
            },
            template: function (value) {
                var emoji = emojis_map[value];
                return '<img alt="' + emoji + '" src="https://static.some.network/images/emoji/' + emoji + '" width="20px" height="20px"/>' + value;
            },
            replace: function (value) {
                return ':' + value + ': ';
            },
            index: 1,
            maxCount: 5,
        }
    ]);
});
