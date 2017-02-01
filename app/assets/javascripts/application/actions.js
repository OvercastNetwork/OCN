$(document).ready(function () {
    $('#action').on('shown.bs.modal', function() {
        $(this).find("textarea:first").focus();
    });

    $(".action").click(function() {
        if($(this).attr("disabled")) return false;

        text = this.innerHTML;
        type = $(this).data("type");
        subtype = $(this).data("subtype")

        switch(type) {
            case "close":
                text = "Close"
                break;
            case "comment":
                break;
        }

        switch(subtype) {
            case "forum":
                description = "Forum: " + text;
                break;
            case "tourney":
                description = "Tourney: " + text;
                break;
            default:
                description = text;
        }

        $("#action-text").text(description);
        $("#action-btn").attr("value", description);
        $("#action-value").attr("value", type);
        $("#action-id").attr("value", $(this).data("id"));
        $("#action-data").attr("value", $("#extra-data").val());
        $("#action-evidence").attr("value", $("#evidence").val());
        $("#action-subtype").attr("value", subtype);
        $("#action-title").attr("value", text);
    });
});
