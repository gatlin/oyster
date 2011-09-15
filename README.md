# Oyster

It contains Perl

(c) 2011 Johnson, Gatlin and Nedelea, Traian

## License

This code is licensed under the GNU General Public License, v3.
To view the license, please visit [its web page](http://www.gnu.org/copyleft/gpl.html).

## Introduction

We had this cool idea and wanted to get it out the door ASAP. Thus, this is
not polished.

Oyster is a simple server which accepts Perl snippets from a Redis list,
redirects STDIN/STDOUT to Redis lists, and `evals` the snippet. The snippet can
naively read / write from / to STDIN / STDOUT (apologies for the awkward sentence).

Each snippet is run in its own separate process. Nothing fancy is used.

The upshot is that a hosted web service could be built on this and interact with 
Oyster via Redis, thus allowing for programming practice in the browser.

Not that the authors of this project intend to do any such thing, of course.

>_>

## Usage

Run ./oyster.

In redis-cli,

    lpush bluequeue "000MAGICMAGICMAGICprint 'Hello!';"
    lrange 000:out 0 -1
    1) "Hello!"

## Limitations

*   No code sanitation
*   Various parameters are hard-coded
*   Had to turn off strict to get a pipe to the forked child.
*   Cannot configure the Redis connection -- yet

## Redis::MessageQueue

We implement a TIEHANDLE for Redis. It is really badass; it might become its
own project. Feel free to use it on its own under the same licensing.
