/**
 * Benchmark with big bucket array (> L3 cache).
 *
 * Copyright: Copyright Martin Nowak 2011 - 2015.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
void main(string[] args)
{
    int[int] aa;
    foreach (_; 0 .. 5)
    {
        foreach (i; 0 .. 1_000_000)
        {
            ++aa[i];
        }
    }
}
