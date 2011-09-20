#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Redis::MessageQueue;

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

# create the master queue which will read in tasks
while (1) {
    tie *QUEUE, 'Redis::MessageQueue', 'bluequeue' or die $!;
    while (<QUEUE>) {
        # read in tasks, fork them off into processes
        my ($id, $code) = split /MAGICMAGICMAGIC/;

        if (pipe_to_child('CHILD')) {
            print "id is $id and code is $code\n";
            print CHILD "$id\n";
            print CHILD "$code\n";
            close CHILD;
        } else {
            my $id = <STDIN>;
            chomp $id;
            my $code = do {local $/; <STDIN>};

            {
                tie local *STDIN, 'Redis::MessageQueue', "$id:in" or
                    croak "Couldn't tie STDIN to [$id]: $!";
                tie local *STDOUT, 'Redis::MessageQueue', "$id:out" or
                    croak "Couldn't tie STDOUT to [$id]: $!";
                tie local *STDERR, 'Redis::MessageQueue', "$id:out" or
                    croak "Couldn't tie STDERR to [$id]: $!";
                local *ARGV = *STDIN;
                eval $code;
            }

            exit(0);
        }
    }
}

