/*
TEST_OUTPUT:
---
fail_compilation/fail3895.d(12): Error: cannot append type `double[]` to type `float[]`
---
*/
import std.stdio;

void main() {
    double[] stuff = [1.,2.,3.,4.,5.];
    float[] otherStuff;
    otherStuff ~= stuff;
    writeln(otherStuff);
}

