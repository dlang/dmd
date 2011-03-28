/**
 * Benchmark on uniformly distributed, random large allocations.
 *
 * Copyright: Copyright David Simcha 2011 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   David Simcha
 */

/*          Copyright David Simcha 2011 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
import std.random, core.memory, std.datetime, std.stdio;

enum nIter = 1000;

void main() {
    auto ptrs = new void*[1024];

    auto sw = StopWatch(autoStart);

    // Allocate 1024 large blocks with size uniformly distributed between 1
    // and 128 kilobytes.
    foreach(i; 0..nIter) {
        foreach(ref ptr; ptrs) {
            ptr = GC.malloc(uniform(1024, 128 * 1024 + 1), GC.BlkAttr.NO_SCAN);
        }
    }

    writefln("RandLarge:  Done %s iter in %s milliseconds.", nIter, sw.peek.msecs);
}
