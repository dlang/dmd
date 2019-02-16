// REQUIRED_ARGS: -de
/* TEST_OUTPUT:
---
fail_compilation/deprecate16597.d(9): Deprecation: variable `deprecate16597.aa1` associative arrays are not thread safe and cant be declared `shared`.Use `__gshared` and barriers instead
fail_compilation/deprecate16597.d(10): Deprecation: variable `deprecate16597.aa2` associative arrays are not thread safe and cant be declared `shared`.Use `__gshared` and barriers instead
---
*/
// https://issues.dlang.org/show_bug.cgi?id=16597
shared int[int] aa1;
shared(int[int]) aa2;
void main ( )
{
    // would segfault
    aa1 = [1:1, 2:2];
}
