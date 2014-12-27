/**
 * Benchmark bulk filling of AA.
 *
 * Copyright: Copyright Martin Nowak 2011 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:    Martin Nowak
 */
import std.random, std.typetuple, std.conv;

version (VERBOSE) import std.datetime, std.stdio;

alias TypeTuple!(ubyte, short, uint, long, void*, Object, ubyte[16], ubyte[64],
                 ubyte[256], ubyte[1024], ubyte[4096], ubyte[16384]
) ValueTuple;

size_t Size = 2 ^^ 20;
size_t trot;

void runTest(V)(ref V v)
{
    version (VERBOSE)
    {
        StopWatch sw;
        writef("%15-s   %8u", V.stringof, Size / V.sizeof);

        void start()
        {
            sw.reset;
            sw.start;
        }

        void stop()
        {
            sw.stop;
            writef(" %5u.%03u", sw.peek.seconds, sw.peek.msecs % 1000);
        }
    }
    else
    {
        static void start() {}
        static void stop() {}
    }

    V[size_t] aa;

    start();
    foreach(k; 0 .. Size / V.sizeof)
    {
        aa[k] = v;
    }
    stop();
    aa.destroy();

    start();
    foreach_reverse(k; 0 .. Size / V.sizeof)
    {
        aa[k] = v;
    }
    stop();
    aa.destroy();

    start();
    foreach(ref k; 0 .. trot * (Size / V.sizeof))
    {
        aa[k] = v;
        k += trot - 1;
    }
    stop();
    aa.clear();

    start();
    foreach_reverse(ref k; 0 .. trot * (Size / V.sizeof))
    {
        k -= trot - 1;
        aa[k] = v;
    }
    stop();
    aa.clear();

    version (VERBOSE) writeln();
}

void main(string[] args)
{
    if (args.length > 1)
        Size = 1 << to!int(args[1]);

    version (RANDOMIZE)
        trot = uniform(1, 200);
    else
        trot = 7;

    version (VERBOSE)
    {
        writefln("==================== Bulk Test ====================");
        writefln("Filling %s KiB, times in s.", Size/1024);
        writefln("Key step %27d | %7d | %7d | %7d", 1, -1, cast(int)trot, -cast(int)trot);
        writefln("%15-s | %8s | %7s | %7s | %7s | %7s",
                "Type", "num", "step", "revstep", "trot", "revtrot");
    };

    ValueTuple valTuple;
    foreach(v; valTuple)
        runTest(v);

    version (VERBOSE)
    {
        writefln("==================== Test Done ====================");
    }
}
