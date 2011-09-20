#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Tatsumaki;
use Tatsumaki::Application;
use Time::HiRes;
use Data::UUID;

package StartHandler;
use base qw(Tatsumaki::Handler);
use Redis::MessageQueue;
use YAML qw(Dump);

sub post {
    my $self = shift;
    my $code = $self->request->parameters->{code};
    my $uuid = Data::UUID->new->create_str();

    tie local *RUNNER, 'Redis::MessageQueue', 'bluequeue';
    print RUNNER Dump({
        type => 'run',
        uuid => $uuid,
        code => $code,
    });
    close RUNNER;

    $self->write([{
            type => "started",
            success => 1,
            uuid => $uuid,
    }]);
}

package KillHandler;
use base qw(Tatsumaki::Handler);
use Redis::MessageQueue;
use YAML qw(Dump);

sub post {
    my ($self,$uuid) = @_;
    my $signal = $self->request->parameters->{signal};

    tie local *RUNNER, 'Redis::MessageQueue', 'bluequeue';
    print RUNNER Dump({
        type => 'signal',
        uuid => $uuid,
        signal => $signal,
    });
    close RUNNER;

    $self->write([{
        type => 'signalled',
        success => 1,
        uuid => $uuid,
    }]);
}

package RecvHandler;
use base qw(Tatsumaki::Handler);
__PACKAGE__->asynchronous(1);
use Redis::MessageQueue;

sub get {
    my ($self,$uuid) = @_;
    my $in = tie local *APPIN, 'Redis::MessageQueue', "$uuid:out";
    $in->poll_once(sub {
        my @messages = @_;
        $self->write([{
            type => "response",
            success => 1,
            response => join("", @messages),
        }]);
        close APPIN;
        $self->finish;
    });
}

package SendHandler;
use base qw(Tatsumaki::Handler);
use Redis::MessageQueue;

sub post {
    my ($self,$uuid) = @_;
    my $input = $self->request->parameters->{input};

    tie local *APPOUT, 'Redis::MessageQueue', "$uuid:in";
    print APPOUT "$input";
    close APPOUT;

    $self->write([{
        type => "sent",
        success => 1,
    }]);
}

package InitHandler;
use base qw(Tatsumaki::Handler);

sub get {
    my $self = shift;
    $self->render('index.html');
}

package main;
use File::Basename;

my $uuid_re = '[A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12}';
my $app = Tatsumaki::Application->new([
    "/start\$" => 'StartHandler',
    "/kill/($uuid_re)" => 'KillHandler',
    "/send/($uuid_re)\$" => 'SendHandler',
    "/recv/($uuid_re)\$" => 'RecvHandler',
    "/\$" => 'InitHandler',
]);

$app->template_path(dirname(__FILE__) . "/templates");
$app->static_path(dirname(__FILE__) . "/static");

return $app->psgi_app;
