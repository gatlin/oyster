#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Redis::MessageQueue;
use YAML qw(Load);
use Data::Dump qw(pp);

# from perlfork
sub pipe_to_child ($) {
    no strict 'refs';
    my $parent = shift;
    pipe my $child, $parent or die;
    my $pid = fork;
    die "fork() failed: $!" unless defined $pid;
    if ($pid) {
        close $child;
    } else {
        close $parent;
        open(STDIN, "<&=" . fileno($child)) or die "$!";
    }
    $pid;
}

my %pid_of;

$SIG{CHLD} = sub {
    local ($!,$?);
    my $pid = waitpid -1, 0;
    return if $pid == -1;
    my %children = reverse %pid_of;
    my $id = $children{$pid};
    return unless $id;
    tie local *APPERR, 'Redis::MessageQueue', "$id:out";
    print APPERR "${id}KILL by signal $?";
    close APPERR;
    delete $pid_of{$id};
};

my %dispatch = (
    run => sub {
        my %op = %{+shift};
        my ($id,$code) = @op{qw(uuid code)};
        if (my $pid = pipe_to_child('CHILD')) {
            $pid_of{$id} = $pid;
            print "id is $id and code is $code\n";
            print CHILD "$id\n";
            print CHILD "$code\n";
            close CHILD;
        } else {
            my $id = <STDIN>;
            chomp $id;
            my $code = do {local $/; <STDIN>};

            tie local *STDIN, 'Redis::MessageQueue', "$id:in" or
                croak "Couldn't tie STDIN to [$id]: $!";
            tie local *STDOUT, 'Redis::MessageQueue', "$id:out" or
                croak "Couldn't tie STDOUT to [$id]: $!";
            local *STDERR = *STDOUT;
            local *ARGV = *STDIN;
            eval $code; warn $@ if $@;

            exit(0);
        }
    },
    signal => sub {
        my %op = %{+shift};
        my ($id,$sig) = @op{qw(uuid signal)};
        kill $sig, $pid_of{$id} if $pid_of{$id};
    },
);

# create the master queue which will read in tasks
tie local *QUEUE, 'Redis::MessageQueue', 'bluequeue' or die $!;
while (<QUEUE>) {
    my $op = Load($_);
    $dispatch{$op->{type}}->($op);
}
close QUEUE;

