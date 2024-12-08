/*
TEST_OUTPUT:
---
fail_compilation/template_enum_param.d(19): Error: static assert:  `false` is false
    static assert(false);
    ^
fail_compilation/template_enum_param.d(21):        instantiated from here: `X!(E.a)`
alias Y = X!(E.a);
          ^
---
*/

enum E
{
    a,b,c
}
template X(E e)
{
    static assert(false);
}
alias Y = X!(E.a);
