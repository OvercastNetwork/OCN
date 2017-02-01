$(document).ready(function () {
    $(".inquiry").click(function() {
        $(".subject").text(this.innerHTML);
        $(".subj").val(this.innerHTML);
    });
});
