#!/usr/bin/env perl

#use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Redis::MessageQueue;

# from perlfork
sub pipe_to_child ($) {
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
    tie *QUEUE, 'Redis::MessageQueue', 'bluequeue' || die $!;
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
            my $code = <STDIN>;
            chomp $id;
            chomp $code;
            tie *CLIENTIN, 'Redis::MessageQueue', "$id:in" || die $!;
            tie *CLIENTOUT,'Redis::MessageQueue', "$id:out" || die $!;

            {
                local *STDIN = *CLIENTIN;
                local *STDOUT= *CLIENTOUT;
                local *ARGV = *CLIENTIN;
                eval $code;
            }
            exit(0);
        }
    }
}

