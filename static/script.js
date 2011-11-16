var editor, UUID;

window.onload = function () {
    editor = ace.edit("editor");
    editor.setTheme('ace/theme/monokai');
    editor.getSession().setMode(new (require('ace/mode/perl').Mode));
    if(localStorage.editor_text)
        editor.getSession().setValue(localStorage.editor_text);
    editor.getSession().on('change', function () {
        localStorage.editor_text = editor.getSession().getValue();
    });
    require('pilot/canon').addCommand({
        name: 'run',
        bindKey: {
            win: 'F2',
            mac: 'F2',
            sender: 'editor',
        },
        exec: function (env, args, request) {
            $('#runwrap #run').trigger('click');
        },
    });
}

var postHandler = function(data) {
    // begin the loop
    UUID = data[0].uuid;

    $.ev.loop('/recv/'+UUID, {
        response: function(ev) {
            var r = ev.response || '';
            if (r.indexOf(UUID) == 0) {
                var message = r.substr(UUID.length);
                if (message.indexOf("KILL") == 0) {
                    $('#runwrap #run').trigger('killed');
                    $.ev.stop();
                }
                $('#response').trigger('output',
                    "\n<span class='meta'>" + message + "</span>\n"
                );
            } else {
                $("#response").trigger('output',r);
            }
        },
    });

    $('#runwrap #run').trigger('running');
};

$(document).ready(function() {
    var socket = io.connect();
    $('#runwrap #run').bind('stopped', function() {
        var self = $(this);
        self.removeAttr('disabled');
        self.text('Run');
        self.one('click', function() {
            $('#response').text('');
            self.trigger('starting');
            $.post('/start',{code: editor.getSession().getValue()},postHandler);
        });
    });

    $('#runwrap #run').bind('starting', function() {
        $(this).unbind('click');
        $(this).attr('disabled','disabled');
        $(this).text('Starting...');
    });

    $('#runwrap #run').bind('running', function() {
        var self = $(this);
        $('#input-buffer').focus();
        self.removeAttr('disabled');
        self.text('Kill');
        self.one('click', function() {
            self.trigger('killing');
            $.post('/kill/'+UUID,{signal: 9}, function(data) {
                self.trigger('killed');
            });
        });
    });

    $('#runwrap #run').bind('killing', function() {
        $(this).unbind('click');
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

    $('#console').click(function(ev) {
        $('#input-buffer').focus();
    });

    $('#response').bind('output', function(ev,output) {
        $(this).append(output);
        $('#console')[0].scrollTop = $('#console')[0].scrollHeight;
    });

    $('#input-buffer').bind('focus keydown mousedown',function(ev) {
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
$('#input-buffer').bind('send', function(ev,value) {
        $('#response').trigger('output',"<span class='input'>" + value + "</span>\n");
        $.post("/send/"+UUID,{input: value}, function(data){});
        $(this).trigger('clear');
    });

    $('#input-buffer').keyup(function(ev) {
        var self = $(this);
        if(ev.which == 13) {    // Enter
            self.trigger('send',self.val());
        }
        if(ev.which == 67 && ev.ctrlKey) {  // C-c
            $('#response').trigger('output','^C');
            $.post('/kill/'+UUID,{signal: 2}, function(data) {});
        }
    });
});
