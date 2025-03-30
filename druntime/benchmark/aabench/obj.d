/**
 * Benchmark class hashing.
 *
 * Copyright: Copyright Martin Nowak 2011 - 2015.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
import std.random;

void main(string[] args)
{
    auto rnd = Xorshift32(33);

    Object[Object] aa;
    auto objs = new Object[](32768);
    foreach (ref o; objs)
        o = new Object;

    foreach (_; 0 .. 10)
    {
        foreach (__; 0 .. 100_000)
        {
            auto k = objs[uniform(0, objs.length, rnd)];
            auto v = objs[uniform(0, objs.length, rnd)];
            aa[k] = v;
        }
    }
    if (aa.length != objs.length)
        assert(0);
}
