/*
TEST_OUTPUT:
---
fail_compilation/fail18892.d(30): Error: no property `foo` for `a` of type `fail18892.MT`
    a.foo = 3;
     ^
fail_compilation/fail18892.d(21):        struct `MT` defined here
struct MT
^
fail_compilation/fail18892.d(31): Error: no property `foo` for `MT` of type `fail18892.MT`
    MT.foo = 3;
      ^
fail_compilation/fail18892.d(21):        struct `MT` defined here
struct MT
^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=18892

struct MT
{
    int _payload;
    alias _payload this;
}

void main()
{
    MT a;
    a.foo = 3;
    MT.foo = 3;
}
