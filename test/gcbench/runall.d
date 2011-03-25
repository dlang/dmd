/**This is a driver script that runs the benchmarks.*/

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
