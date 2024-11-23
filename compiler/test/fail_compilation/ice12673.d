/*
TEST_OUTPUT:
---
fail_compilation/ice12673.d(15): Error: static assert:  `__traits(compiles, () pure nothrow @nogc @safe
{
__error__
}
)` is false
    static assert(__traits(compiles, { abcd(); }));
    ^
---
*/
void main()
{
    static assert(__traits(compiles, { abcd(); }));
}
