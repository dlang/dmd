/*
TEST_OUTPUT:
---
fail_compilation/fail19103.d(24): Error: no property `puts` for `new C` of type `fail19103.C`
    (new C).puts("OK."); // Error: no property puts for type test.C, did you mean core.stdc.stdio.puts(T...)(T args)?
           ^
fail_compilation/fail19103.d(36):        class `C` defined here
class C
^
fail_compilation/fail19103.d(26): Error: no property `puts` for `s1` of type `fail19103.S1`
    s1.puts("Hey?"); // It can be compiled and runs!
      ^
fail_compilation/fail19103.d(40):        struct `S1` defined here
struct S1
^
fail_compilation/fail19103.d(28): Error: no property `puts` for type `S2`, did you mean `core.stdc.stdio.puts`?
    s2.puts("OK."); //  Error: no property puts for type S2, did you mean core.stdc.stdio.puts(T...)(T args)?
      ^
---
*/

void main()
{
    (new C).puts("OK."); // Error: no property puts for type test.C, did you mean core.stdc.stdio.puts(T...)(T args)?
    S1 s1;
    s1.puts("Hey?"); // It can be compiled and runs!
    S2 s2;
    s2.puts("OK."); //  Error: no property puts for type S2, did you mean core.stdc.stdio.puts(T...)(T args)?
}

mixin template T()
{
    import core.stdc.stdio;
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
    import core.stdc.stdio;
}
