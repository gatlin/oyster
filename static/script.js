var editor, UUID;

window.onload = function () {
    editor = ace.edit("editor");
};

var getContents = function() {
    return document.getElementById("editor").env.document.getValue();
};

var postHandler = function(data) {
    // begin the loop
    UUID = data[0].uuid;
    $('#runwrap #run').remove();
    $('#runwrap').append("<button class='kill' id='"+UUID+"'>Kill</button>");

    $.ev.loop('/recv/'+UUID, {
        response: function(ev) {
            var r = ev.response.replace(/\n/g,"<br/>");
            if (r.indexOf(UUID) >= 0) {
                var message = r.substr(UUID.length);
                if (message.indexOf("KILL") == 0) {
                    $('#runwrap #'+UUID).remove();
                    $('#runwrap').append("<button id='run'>Run</button>");
                    $.ev.stop();
                }
                $('#response').append(
                    "<div class='meta'>" + message + "</div>"
                );
            } else {
                $("#response").append(r);
            }
            $("#response")[0].scrollTop = $("#response")[0].scrollHeight;
        },
    });
};

$(document).ready(function() {
    $('#runwrap #run').live('click',function() {
        $('#response').text('');
        $.post("/start",{code: getContents()},postHandler);
    });

    $('#runwrap .kill').live('click',function() {
        var id = $(this).attr('id');
        $.post(
            "/kill/"+id,
            {signal: 9},
            function(data) {
            }
        );
    });

    $('#send').click(function() {
        $.post("/send/"+UUID,{input:$("#theInput").val()},function(d) {
        });
    });

});
