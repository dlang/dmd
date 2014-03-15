/*
TEST_OUTPUT:
---
fail_compilation/test313.d(13): Error: undefined identifier writefln
fail_compilation/test313.d(16): Error: undefined identifier std
---
*/
import imports.test313a;

void main()
{
    // compiler correctly reports "undefined identifier writefln"
    writefln("foo");

    // works fine! --> correctly reports "undefined identifier std"
    std.stdio.writefln("foo");
}
