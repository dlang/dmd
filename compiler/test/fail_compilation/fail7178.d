/*
TEST_OUTPUT:
---
fail_compilation/fail7178.d(14): Error: undefined identifier `contents` in module `fail7178`
    mixin populate!(.contents);
    ^
fail_compilation/fail7178.d(16): Error: mixin `fail7178.populate!int` error instantiating
public mixin populate!int;
       ^
---
*/
template populate(overloads...)
{
    mixin populate!(.contents);
}
public mixin populate!int;
