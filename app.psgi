#!/usr/bin/env perl

use v5.014;
use strict;
use warnings;

my $root;

# cargo-culted from the pocketio source
BEGIN {
    use File::Basename ();
    use File::Spec ();

    $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);
}

use PocketIO;
use PocketIO::Pool::Redis;

use JSON;
use Plack::App::File;
use Plack::Builder;
use Plack::Middleware::Static;

builder {
    # file includes
    mount '/' =>
        Plack::App::File->new(file => "$root/templates/index.html");

    mount '/static/style.css' =>
        Plack::App::File->new(file => "$root/static/style.css");

    mount '/static/ace/ace.js' =>
        Plack::App::File->new(file => "$root/static/ace/ace.js");

    mount '/static/ace/theme-monokai.js' =>
        Plack::App::File->new(file => "$root/static/ace/theme-monokai.js");

    mount '/static/ace/mode-perl.js' =>
        Plack::App::File->new(file => "$root/static/ace/mode-perl.js");

    mount '/static/script.js' =>
        Plack::App::File->new(file => "$root/static/script.js");

    mount '/socket.io/socket.io.js' =>
        Plack::App::File->new(file => "$root/static/socket.io.js");

    mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
        Plack::App::File->new(file => "$root/static/WebSocketMain.swf");

    mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
        Plack::App::File->new(file =>
            "$root/static/WebSocketMainInsecure.swf");

    # actual event handling

    mount '/socket.io' => PocketIO->new(
        pool => PocketIO::Pool::Redis->new,
        handler => sub {
            my $self = shift;

            $self->on(
                'start' => sub {
                    use Data::UUID;
                    use Redis::Handle;
                    use YAML qw(Dump);

                    my ($self,$code) = @_;
                    my $uuid = Data::UUID->new->create_str();
                    tie local *RUNNER, 'Redis::Handle', 'bluequeue';
                    print RUNNER Dump({
                        type => 'run',
                        uuid => $uuid,
                        code => $code,
                    });
                    close RUNNER;
                    $self->send(PocketIO::Message->new(
                            type => 'event',
                            data => {
                                name => 'started',
                                args => {
                                    uuid => $uuid,
                                    success => 1,
                                },
                            },
                        )
                    );
                }
            );

            $self->on(
                'recv' => sub {
                    use Redis::Handle;
                    my ($self,$uuid) = @_;

                    my $in = tie local *APPIN, 'Redis::Handle', "$uuid:out";

                    $in->poll_once(sub {
                        my @messages = @_;
                        map {
                            $self->send(PocketIO::Message->new(
                                    type => 'event',
                                    data => {
                                        name => 'recvd',
                                        args => {
                                            response => $_,
                                            success => 1,
                                        },
                                    },
                                )
                            );
                        } @messages;
                        close APPIN;
                    });
                }
            );

            $self->on(
                'kill' => sub {
                    use Redis::Handle;
                    use YAML qw/Dump/;

                    my ($self,$uuid,$signal) = @_;

                    tie local *RUNNER, 'Redis::Handle', 'bluequeue';
                    print RUNNER Dump({
                        type => 'signal',
                        uuid => $uuid,
                        signal => $signal,
                    });
                    close RUNNER;

                    $self->send(PocketIO::Message->new(
                            type => 'event',
                            data => {
                                name => 'signalled',
                                args => {
                                    success => 1,
                                    uuid => $uuid,
                                },
                            },
                        )
                    );
                }
            );

            $self->on(
                'send' => sub {
                    use Redis::Handle;
                    my ($self,$uuid,$input);

                    tie local *APPOUT, 'Redis::Handle', "$uuid:in";
                    print APPOUT "$input";
                    close APPOUT;

                    $self->send(PocketIO::Message->new(
                            type => 'event',
                            data => {
                                name => 'sent',
                                args => {
                                    success => 1,
                                },
                            }
                        )
                    );
                }
            );
        }
    );
}
