/**
 * Benchmark hash with cache stomping.
 *
 * Copyright: Copyright Martin Nowak 2015 - .
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
import std.file, std.algorithm, std.random, std.math;

// exponential distribution around mean
struct ExpRandom
{
    double mean;
    Xorshift32 gen;

    this(double mean)
    {
        this.mean = mean;
        gen = Xorshift32(unpredictableSeed);
    }

    size_t front()
    {
        return cast(size_t)(mean * -log(uniform!"()"(0.0, 1.0, gen)) + 0.5);
    }

    alias gen this;
}

struct CacheStomper
{
    ExpRandom rnd;
    size_t i;
    ubyte[] mem;

    this(size_t avgBytesPerCall)
    {
        rnd = ExpRandom(avgBytesPerCall / 64.0);
        mem = new ubyte[](32 * 1024 * 1024);
    }

    void stomp()
    {
        immutable n = rnd.front();
        rnd.popFront();
        foreach (_; 0 .. n)
            ++mem[(i += 64) & ($ - 1)];
    }
}

void main(string[] args)
{
    auto path = args.length > 1 ? args[1] : "extra-files/dante.txt";
    auto words = splitter(cast(string) read(path), ' ');

    size_t[string] aa;
    auto stomper = CacheStomper(1000);
    foreach (_; 0 .. 10)
    {
        foreach (word; words)
        {
            ++aa[word];
            stomper.stomp();
        }
    }
}
