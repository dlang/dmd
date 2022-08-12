/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test20956.d(105): Error: function `test20956.forwardDg` cannot close over `ref` variable `c`
---
 */

// https://issues.dlang.org/show_bug.cgi?id=20956

#line 100

@safe:

alias DG = void delegate() @safe;

DG forwardDg(ref int c)
{
    return () {assert(c == 42);};
}
