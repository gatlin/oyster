var editor, UUID;

window.onload = function () {
    editor = ace.edit("editor");
    if(localStorage.editor_text)
        setContents(localStorage.editor_text);
}

var getContents = function() {
    return document.getElementById("editor").env.document.getValue();
};

var setContents = function(value) {
    return $('#editor')[0].env.document.setValue(value);
};

var postHandler = function(data) {
    // begin the loop
    UUID = data[0].uuid;

    $.ev.loop('/recv/'+UUID, {
        response: function(ev) {
            var r;
            if (ev.response) r = ev.response.replace(/\n/g,"<br/>");
            else r = '';
            if (r.indexOf(UUID) >= 0) {
                var message = r.substr(UUID.length);
                if (message.indexOf("KILL") == 0) {
                    $('#runwrap #run').trigger('killed');
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

    $('#runwrap #run').trigger('running');
};

$(document).ready(function() {
    $('#runwrap #run').bind('stopped', function() {
        var self = $(this);
        self.removeAttr('disabled');
        self.text('Run');
        self.unbind('click');
        self.one('click', function() {
            $('#response').text('');
            self.trigger('starting');
            $.post('/start',{code: getContents()},postHandler);
        });
    });

    $('#runwrap #run').bind('starting', function() {
        $(this).attr('disabled','disabled');
        $(this).text('Starting...');
    });

    $('#runwrap #run').bind('running', function() {
        var self = $(this);
        $('#input-buffer').focus();
        self.removeAttr('disabled');
        self.text('Kill');
        self.unbind('click');
        self.one('click', function() {
            self.trigger('killing');
            $.post('/kill/'+UUID,{signal: 9}, function(data) {
                self.trigger('killed');
            });
        });
    });

    $('#runwrap #run').bind('killing', function() {
        $(this).attr('disabled','disabled');
        $(this).text('Killing...');
    });

    $('#runwrap #run').bind('killed', function() {
        var self = $(this);
        self.attr('disabled','disabled');
        self.text('Killed');
        $('#editor textarea').focus();
        setTimeout(function() {
            self.trigger('stopped');
        },1000);
    });
    $('#runwrap #run').trigger('stopped');      // Initial state is stopped.

    $('#editor').focusout(function(ev) {
        localStorage.editor_text = getContents();
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
