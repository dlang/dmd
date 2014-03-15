/*
TEST_OUTPUT:
---
fail_compilation/test314.d(16): Error: undefined identifier std
fail_compilation/test314.d(17): Error: undefined identifier io
fail_compilation/test314.d(18): Error: undefined identifier writefln
---
*/

import imports.test314a;
import imports.test314b;
import imports.test314c;

void main()
{
    std.stdio.writefln("This should not work.");
    io.writefln("This should not work.");
    writefln("This should not work.");
}
