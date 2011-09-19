#!/usr/bin/perl

package Redis::MessageQueue;

use strict;
use warnings;
use Time::HiRes;
use AnyEvent::Redis;
use Redis;
use Storable qw(nfreeze thaw);
use Data::Dump qw(pp);

{
	my $timeout = 5;
	my $redis;
	my %redis;

=head2 TIEHANDLE

Ties the filehandle to the clientId in Redis.

=head3 Usage

	tie *CLIENT, "Redis::MessageQueue", $clientId;

=cut
	sub TIEHANDLE {
		my ($class,$clientId) = (+shift,+shift);
		%redis = @_;
		$redis ||= Redis->new(%redis);
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
        foreach (@_) {
		    $redis->lpush($$this, $_);
        }
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
	sub blocking_readline {
		my $this = shift;
        my $fn = pop;
		my $r = AnyEvent::Redis->new(%redis);
		$r->brpop($$this, $timeout, sub {

            use Data::Dump qw(pp);
            warn pp @_;

			my $message = $_[0][1];
            return $fn->($message);
		});
	}

	sub READLINE {
		my $this = shift;
		my $r = AnyEvent::Redis->new(%redis);
		my $message;
		my $cv = $r->brpop($$this, $timeout, sub {
			$message = $_[0][1];
		});
		$cv->recv;
		return $message unless wantarray;
		return ($message, _flush($this));
	}

	sub _flush {
		my $this = shift;
		return () unless _len($this);
		my $message = $redis->rpop($$this);
		return ($message, _flush($this));
	}

	sub _len {
		my $this = shift;
		my $len = $redis->llen($$this);
		return $len;
	}
}

1;
