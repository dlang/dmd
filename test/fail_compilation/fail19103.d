/*
TEST_OUTPUT:
---
fail_compilation/fail19103.d(15): Error: no property `writeln` for type `fail19103.C`, did you mean `std.stdio.writeln(T...)(T args)`?
fail_compilation/fail19103.d(17): Error: no property `writeln` for type `S1`, did you mean `std.stdio.writeln(T...)(T args)`?
fail_compilation/fail19103.d(19): Error: no property `writeln` for type `S2`, did you mean `std.stdio.writeln(T...)(T args)`?
---
*/

// Note: This test fails because imports are private.
// There is compilable/test19103.d using public.

void main()
{
    (new C).writeln("OK."); // Error: no property writeln for type test.C, did you mean std.stdio.writeln(T...)(T args)?
    S1 s1;
    s1.writeln("Hey?"); // It can be compiled and runs!
    S2 s2;
    s2.writeln("OK."); //  Error: no property writeln for type S2, did you mean std.stdio.writeln(T...)(T args)?
}

mixin template T()
{
    import std.stdio;
}

class C
{
    mixin T;
}
struct S1
{
    mixin T;
}

struct S2
{
    import std.stdio;
}
