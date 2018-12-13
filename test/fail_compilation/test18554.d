/* REQUIRED_ARGS: -dip1000
TEST_OUTPUT:
---
fail_compilation/test18554.d(15): Error: struct `imp18554.S` member `i` is not accessible from `@safe` code
---
*/

// https://issues.dlang.org/show_bug.cgi?id=18554

import imports.imp18554;

void test1() @safe
{
    S s;
    s.tupleof[0] = 1;
}

void test2()
{
    S s;
    s.tupleof[0] = 1;
}

