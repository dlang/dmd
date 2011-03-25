/**Another tree building benchmark.  Thanks again to Bearophile.*/

import std.stdio, std.container, std.range, std.datetime;

void main() {
    auto sw = StopWatch(autoStart);
    enum int range = 100;
    enum int n = 1_000_000;

    auto t = RedBlackTree!int(0);

    for (int i = 0; i < n; i++) {
        if (i > range)
            t.removeFront();
        t.insert(i);
    }

    writeln("Tree2:  ", sw.peek.seconds, " seconds");
}

