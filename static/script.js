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
                $('#response').trigger('output',
                    "<span class='meta'>" + message + "</span><br />"
                );
            } else {
                $("#response").trigger('output',r);
            }
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

    $('#console').click(function(ev) {
        $('#input-buffer').focus();
    });

    $('#response').bind('output', function(ev,output) {
        $(this).append(output);
        $('#console')[0].scrollTop = $('#console')[0].scrollHeight;
    });

    $('#input-buffer').keydown(function(ev) {
        $(this).trigger('resize');
    });

    $('#input-buffer').bind('resize', function(ev) {
        $(this)[0].size = $(this).val().length + 1;
    });

    $('#input-buffer').bind('set', function(ev,value) {
        $(this).val(value);
        $(this).trigger('resize');
    });

    $('#input-buffer').bind('clear', function(ev) {
        $(this).trigger('set','');
    });

    $('#input-buffer').keyup(function(ev) {
        var self = $(this);
        if(ev.which == 13) {    // Enter
            $('#response').trigger('output',"<span class='input'>" + self.val() + "</span><br />");
            $.post("/send/"+UUID,{input:self.val()}, function(data){});
            $('#input-buffer').trigger('clear');
        }
    });
});
