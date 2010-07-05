// PERMUTE_ARGS:

import std.stdio;
import std.algorithm;

void main()
{
    int[] a = [1,2,3,4,5];
    writeln( remove!("a < 3")(a) );
}
