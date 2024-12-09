/*
TEST_OUTPUT:
---
fail_compilation/fail249.d(18): Error: invalid `foreach` aggregate `bar()` of type `void`
    foreach (Object o; bar())
    ^
---
*/

module main;

public void bar()
{
}

void main()
{
    foreach (Object o; bar())
    {
        debug Object foo = null; //error
    }
}
