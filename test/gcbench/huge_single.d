/**
 * Benchmark on one huge allocation.
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
import std.stdio, std.datetime, core.memory;

void main(string[] args) {
    enum mul = 1000;
    auto ptr = GC.malloc(mul * 1_048_576, GC.BlkAttr.NO_SCAN);

    auto sw = StopWatch(autoStart);
    GC.collect();
    immutable msec = sw.peek.msecs;
    writefln("HugeSingle:  Collected a %s megabyte heap in %s milliseconds.",
             mul, msec);
}
