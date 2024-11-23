// EXTRA_SOURCES: imports/fail2962a.d

// comment 6
/*
TEST_OUTPUT:
---
fail_compilation/fail2962.d(25): Error: variable `y` cannot be read at compile time
    return baz6!(T, y)();
           ^
fail_compilation/fail2962.d(25):        while looking for match for `baz6!(int, y)`
fail_compilation/fail2962.d(33): Error: template instance `fail2962.bar6!int` error instantiating
    assert(bar6(4) != 0);
               ^
fail_compilation/fail2962.d(38): Error: variable `x` cannot be read at compile time
    return baz4!(T, x)();
           ^
fail_compilation/fail2962.d(38):        while looking for match for `baz4!(int, x)`
fail_compilation/imports/fail2962a.d(6): Error: template instance `fail2962.bar4!int` error instantiating
    return bar4(0);
               ^
---
*/
T bar6(T)(T y)
{
    return baz6!(T, y)();
}
T baz6(T, T z)()
{
    return z * z;
}
void test6()
{
    assert(bar6(4) != 0);
}

T bar4(T)(T x)
{
    return baz4!(T, x)();
}
T baz4(T, T x)()
{
    return x;
}
