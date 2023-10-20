/**
 * Benchmark on one huge allocation.
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
import std.stdio, core.memory;

void main(string[] args) {
    enum mul = 1000;
    auto ptr = GC.malloc(mul * 1_048_576, GC.BlkAttr.NO_SCAN);

    GC.collect();
}
