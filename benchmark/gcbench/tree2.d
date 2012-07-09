/**
 * Another tree building benchmark.  Thanks again to Bearophile.
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
import std.stdio, std.container, std.range;

void main() {
    enum int range = 100;
    enum int n = 1_000_000;

    auto t = redBlackTree!int();

    for (int i = 0; i < n; i++) {
        if (i > range)
            t.removeFront();
        t.insert(i);
    }
}

