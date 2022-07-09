/**
 * Benchmark AA with big values.
 *
 * Copyright: Copyright Martin Nowak 2011 - 2015.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
void main(string[] args)
{
    static struct V { ubyte[1024] data; }
    V[int] aa;
    V v;
    foreach (_; 0 .. 10)
        foreach (i; 0 .. 100_000)
            aa[i] = v;
}
