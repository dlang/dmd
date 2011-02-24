/**This is a driver script that runs the benchmarks.*/

import std.stdio, std.process;

void main() {
    system("dmd -O -inline -release singleHuge.d");
    system("dmd -O -inline -release largeRand.d");
    system("dmd -O -inline -release smallRand.d");
    system("dmd -O -inline -release tree1.d");
    system("dmd -O -inline -release tree2.d");

    system("singleHuge");
    system("largeRand");
    system("smallRand");
    system("tree1");
    system("tree2");
}
