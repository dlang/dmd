/*
TEST_OUTPUT:
---
fail_compilation/fail15.d(26): Error: cannot use `[]` operator on expression of type `void`
    bool x = xs[false];
               ^
---
*/
/*
Segfault on DMD 0.095
https://www.digitalmars.com/d/archives/digitalmars/D/bugs/926.html
*/
module test;

template Test()
{
    bool opIndex(bool x)
    {
        return !x;
    }
}

void main()
{
    mixin Test!() xs;
    bool x = xs[false];
}
