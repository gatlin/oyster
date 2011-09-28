#!/usr/bin/perl

package Redis::MessageQueue;

use strict;
use warnings;
use Carp;
use Time::HiRes;
use AnyEvent::Redis;
use Redis;
use Storable qw(nfreeze thaw);

# use Data::Dump qw(pp);

{
	my $timeout = 30;   # For BLPOPs, in seconds
	my $redis;          # We want only a single Redis connection
	my %redis;          # Connection information
    my $keepalive;      # So Redis doesn't drop us on the floor

=head2 TIEHANDLE

Ties the filehandle to the clientId in Redis.

=head3 Usage

	tie *CLIENT, "Redis::MessageQueue", $clientId;

    tie *CLIENT, 'Redis::MessageQueue', $clientId,
        timeout => 100,
        host => 'example.com',
        port => 5800;

=cut

	sub TIEHANDLE {
		my ($class,$clientId) = (+shift,+shift);
		%redis = @_;
        $redis ||= Redis->new(%redis);

        if ($redis{timeout}) {
            $timeout = $redis{timeout};
            delete $redis{timeout};
        }

		bless \$clientId, $class;
	}

=head2 PRINT

Sends the message(s) to the client. Since we're using an AnyEvent connection,
events are still processed while waiting on Redis to process the push,
including asynchronously pushing _other_ messages.

=head3 Usage

	print CLIENT { text => "foo", from => "bar" };
	print CLIENT { text => "foo" }, { text => "bar" }, "System message";

=cut
	sub PRINT {
		my $this = shift;
        eval { $redis->ping };
        $redis = Redis->new(%redis) if $@;
        foreach (@_) {
            $redis->lpush($$this, $_) or
                croak qq{Failed to push message [$_] to [$$this]: $!};
        }
        return 1;
	}

=head2 READLINE

Reads the next message or flushes the message queue (depending on context).
This is a "blocking" operation, but, because we're using AnyEvent::Redis, other
events are still processed while we wait. Since Redis's C<BLPOP> operation
blocks the whole connection, this spawns a separate AnyEvent::Redis connection
to deal with the blocking operation.

=head3 Usage

	my $message = <CLIENT>;     # Reads only the next one
	my @messages = <CLIENT>;    # Flushes the message queue into @messages

=cut
	sub READLINE {
		my $this = shift;
        eval { $redis->ping };
        $redis = Redis->new(%redis) if $@;
		my $r = AnyEvent::Redis->new(%redis) or
            croak qq(Couldn't create AnyEvent::Redis connection to [@{[%redis]}]: $!);
		my $message;
		my $cv = $r->brpop($$this, $timeout, sub {
			$message = $_[0][1];
		}) or croak qq{Couldn't BRPOP from [$$this]: $!};
		$cv->recv;
        $r->quit; undef $r;
		return $message unless wantarray;
		return ($message, _flush($this));
	}

=for READLINE

Helper methods for READLINE

If you pass C<_flush> a nonzero number, it will read that many messages. An
explicit "0" means "read nothing", while an C<undef> means "read everything".

=cut
	sub _flush {
		my ($this,$count) = @_;
        my @messages;
        while (my $m = $redis->rpop($$this)) {
            last if defined $count && --$count < 0;
            push @messages, $m;
        }
		return @messages;
	}

=head2 EOF

Just like the regular C<eof> call. Returns 1 if the next read will be the end
of the queue or if the queue isn't open.

=cut
    sub EOF {
        my $this = shift;
        return not _len($this);
    }

=for EOF,READLINE

Returns the length of the buffer.

=cut
	sub _len {
		my $this = shift;
		return $redis->llen($$this);
	}

=head2 poll_once

Returns the C<AnyEvent::Condvar> of the a blocking pop operation on a Redis queue.
This is useful if, for example, you want to handle a C<BLPOP> as an asynchronous
PSGI handler, since a standard C<READLINE> operation throws a "recursive blocking
wait" exception (because you're waiting on a C<CondVar> that's waiting on a
C<CondVar>). It takes a C<tied> variable, an optional C<count> of the maximum
number of messages to return, and a callback as its arguments.

=head3 Usage

    sub get {
        my ($self,$clientId) = (+shift,+shift);
        my $output = tie local *CLIENT, 'Redis::MessageQueue', "$clientId:out";
        $output->poll_once(sub {
            $self->write(+shift);
            $self->finish;
        });
    }

=cut
	sub poll_once {
        my $fn = pop;
		my ($this,$count) = @_;
		my $r = AnyEvent::Redis->new(%redis);
		$r->brpop($$this, $timeout, sub {
			my $message = $_[0][1];
            $r->quit; undef $r;
            return $fn->($message, _flush($this,$count));
		});
	}

=head2 READ

A builtin version of C<poll_once>. It takes the same arguments as C<poll_once>,
which are not the usual arguments for C<read>.

=head3 Usage

    sub get {
        my ($self,$clientId) = @_;
        tie local *CLIENT, 'Redis::MessageQueue', "$clientId:out";
        read *CLIENT, sub {
            $self->write(+shift);
            $self->finish;
        };
    }

=cut
    sub READ {
        my $fn = pop;
        my ($this,$count) = @_;
        $this->poll_once($count,$fn);
    }

=head2 CLOSE

Cleanup code so that we don't end up with a bunch of open filehandles.

=cut
    sub CLOSE {
        # The elements of @_ are *aliases*, not copies, so undefing $_[0] marks
        # the caller's typeglob as empty.
        $redis->ping;
        undef $_[0];
    }

}
1;
