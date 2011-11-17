#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Redis::Handle;
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
    tie local *APPERR, 'Redis::Handle', "$id:out";
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

            {
                tie local *STDIN, 'Redis::Handle', "$id:in" or
                    croak "Couldn't tie STDIN to [$id]: $!";
                tie local *STDOUT, 'Redis::Handle', "$id:out" or
                    croak "Couldn't tie STDOUT to [$id]: $!";
                tie local *STDERR, 'Redis::Handle', "$id:out" or
                    croak "Couldn't tie STDERR to [$id]: $!";
                local *ARGV = *STDIN;
                eval $code;
            }

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
while (1) {
    tie local *QUEUE, 'Redis::Handle', 'bluequeue' or die $!;
    while (<QUEUE>) {
        my $op = Load($_);
        $dispatch{$op->{type}}->($op);
    }
    close QUEUE;
}
close QUEUE;

