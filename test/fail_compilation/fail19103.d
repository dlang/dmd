/*
TEST_OUTPUT:
---
fail_compilation/fail19103.d(12): Error: no property `writeln` for type `fail19103.C`, perhaps `import std.stdio;` is needed?
fail_compilation/fail19103.d(14): Error: no property `writeln` for type `S1`, perhaps `import std.stdio;` is needed?
fail_compilation/fail19103.d(16): Error: no property `writeln` for type `S2`, did you mean `std.stdio.writeln(T...)(T args)`?
---
*/

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
