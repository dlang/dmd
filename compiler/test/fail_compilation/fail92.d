/*
TEST_OUTPUT:
---
fail_compilation/fail92.d(19): Error: invalid `foreach` aggregate `t` of type `typeof(null)`
        foreach (u; t)
        ^
fail_compilation/fail92.d(27): Error: template instance `fail92.crash!(typeof(null))` error instantiating
    crash(null);
         ^
---
*/

// [25]

template crash(T)
{
    void crash(T t)
    {
        foreach (u; t)
        {
        }
    }
}

void main()
{
    crash(null);
}
