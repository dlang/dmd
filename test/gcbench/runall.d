/**
 * This is a driver script that runs the benchmarks.
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
import std.stdio, std.process;

void main() {
    system("dmd -O -inline -release huge_single.d");
    system("dmd -O -inline -release rand_large.d");
    system("dmd -O -inline -release rand_small.d");
    system("dmd -O -inline -release tree1.d");
    system("dmd -O -inline -release tree2.d");

    system("huge_single");
    system("rand_large");
    system("rand_small");
    system("tree1");
    system("tree2");
}
