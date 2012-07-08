/**
 * Benchmark increasing/decreasing AA size.
 *
 * Copyright: Copyright Martin Nowak 2011 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:    Martin Nowak
 */

import std.random;

enum Count = 1_000;
enum MinSize = 512;
enum MaxSize = 16_384;

void runTest(Random gen)
{
    bool[uint] aa;

    sizediff_t diff = MinSize;
    size_t cnt = Count;

    do
    {
        while (diff > 0)
        {
            auto key = uniform(0, MaxSize, gen);
            if (!(key in aa))
            {
                aa[key] = true;
                --diff;
            }
        }

        while (diff < 0)
        {
            auto key = uniform(0, MaxSize, gen);
            if (!!(key in aa))
            {
                aa.remove(key);
                ++diff;
            }
        }

        auto nsize = uniform(MinSize, MaxSize, gen);
        diff = nsize - aa.length;

    } while (--cnt);
}

void main()
{
    version (RANDOMIZE)
        auto gen = Random(unpredictableSeed);
    else
        auto gen = Random(12);
    runTest(gen);
}
