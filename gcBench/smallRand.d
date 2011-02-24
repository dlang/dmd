/**Benchmark on uniformly distributed, random small allocations.*/

import std.random, core.memory, std.datetime, std.stdio;

enum nIter = 1000;

void main() {
    auto ptrs = new void*[4096];

    auto sw = StopWatch(autoStart);

    // Allocate 1024 large blocks with size uniformly distributed between 8
    // and 2048 bytes.
    foreach(i; 0..nIter) {
        foreach(ref ptr; ptrs) {
            ptr = GC.malloc(uniform(8, 2048), GC.BlkAttr.NO_SCAN);
        }
    }

    writefln("SmallRand:  Done %s iter in %s milliseconds.", nIter, sw.peek.msecs);
}
