# Oyster

It contains Perl

(c) 2011 Johnson, Gatlin and Nedelea, Traian

## License

This code is licensed under the GNU General Public License, v3.
To view the license, please visit [its web page](http://www.gnu.org/copyleft/gpl.html).

## Introduction

We had this cool idea and wanted to get it out the door ASAP. So, without too much egregious apology, we'd like to 
come clean that this is not a finished product - but it's functional!

Oyster is a forking server which remotely runs Perl code. It makes the program's STDIN and STDOUT available
as Redis lists, and communicates with its frontend via Redis as well.

The upshot is that you can write naive Perl code and run it *interactively* in the browser. This doesn't simply eval
code and print the output: you can accept textual input in real time. We think this is neat.

We have written an example web application using Tatsumaki; the relevant code is in app.psgi (and usage is below). It
exists to showcase the current features of oyster. We encourage people to come up with their own frontends to oyster
for any purpose they see fit.

## Usage

First, install and run Redis. This is left as an exercise for the reader.Then, run oyster:

    ./oyster.pl

and technically you're done. But it's useless without a frontend interface.

We have a simple PSGI-based web interface. We recommend running with plackup, eg

    plackup app.psgi -s Twiggy
    
Useful modules to have installed:

* Plack
* Plack::Handler::Twiggy
* Data::Dump
* Data::UUID
* Text::MicroTemplate::File
* Any::Moose
* JSON
* YAML
* Redis
* AnyEvent::Redis

We include our custom Redis tiehandle class and the Tatsumaki framework in `lib/`. 

### Redis::MessageQueue

Part of the magic sauce is a custom Redis tiehandle class which oyster uses extensively, and which can easily be
used in your own web frontend (we use it in ours). Example usage:

    tie my *REDISIN, "Redis::MessageQueue", 'keyname', host => 127.0.0.1, port => 6739;

You can also do things like this ...

    tie local *STDIN, 'Redis::MessageQueue', 'channel:in';

... which is what we do in oyster.

## Limitations

*   No code sanitation
*   Had to turn off strict to get a pipe to the forked child.

## Roadmap

See the "Issues" page on GitHub.
