/**
 * Benchmark ptr hashing.
 *
 * Copyright: Copyright Martin Nowak 2011 - 2015.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
import std.random;

void main(string[] args)
{
    auto rnd = Xorshift32(33);

    int[int* ] aa;
    auto keys = new int*[](32768);
    foreach (ref k; keys)
        k = new int;

    foreach (_; 0 .. 10)
        foreach (__; 0 .. 100_000)
            ++aa[keys[uniform(0, keys.length, rnd)]];

    if (aa.length != keys.length)
        assert(0);
}
