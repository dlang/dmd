/**
 * Benchmark on uniformly distributed, random large allocations.
 *
 * Copyright: Copyright David Simcha 2011 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   David Simcha
 */

/*          Copyright David Simcha 2011 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
import std.random, core.memory, std.stdio;

enum nIter = 10000;

void main()
{
    version (RANDOMIZE)
        auto rnd = Random(unpredictableSeed);
    else
        auto rnd = Random(1202387523);

    auto ptrs = new void*[1024];

    // Allocate 1024 large blocks with size uniformly distributed between 1
    // and 128 kilobytes.
    foreach(i; 0..nIter)
    {
        foreach(ref ptr; ptrs)
        {
            immutable sz = uniform(1024, 128 * 1024 + 1, rnd);
            ptr = GC.malloc(sz, GC.BlkAttr.NO_SCAN);
        }
    }
}
