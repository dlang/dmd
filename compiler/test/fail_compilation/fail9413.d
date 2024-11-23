/*
TEST_OUTPUT:
---
fail_compilation/fail9413.d(81): Error: variable `fail9413.foo.x` cannot modify parameter `x` in contract
        x = 10; // err
        ^
fail_compilation/fail9413.d(68): Error: variable `fail9413.foo.x` cannot modify parameter `x` in contract
        x = 10; // err
        ^
fail_compilation/fail9413.d(69): Error: variable `fail9413.foo.bar.y` cannot modify parameter `y` in contract
        y = 10; // err
        ^
fail_compilation/fail9413.d(74): Error: variable `fail9413.foo.x` cannot modify parameter `x` in contract
        x = 10; // err
        ^
fail_compilation/fail9413.d(75): Error: variable `fail9413.foo.bar.y` cannot modify parameter `y` in contract
        y = 10; // err
        ^
fail_compilation/fail9413.d(76): Error: variable `fail9413.foo.bar.s` cannot modify result `s` in contract
        s = 10; // err
        ^
fail_compilation/fail9413.d(86): Error: variable `fail9413.foo.x` cannot modify parameter `x` in contract
    x = 10; // err
    ^
fail_compilation/fail9413.d(109): Error: variable `fail9413.foo.x` cannot modify parameter `x` in contract
        x = 10; // err
        ^
fail_compilation/fail9413.d(110): Error: variable `fail9413.foo.r` cannot modify result `r` in contract
        r = 10; // err
        ^
fail_compilation/fail9413.d(94): Error: variable `fail9413.foo.x` cannot modify parameter `x` in contract
        x = 10; // err
        ^
fail_compilation/fail9413.d(95): Error: variable `fail9413.foo.r` cannot modify result `r` in contract
        r = 10; // err
        ^
fail_compilation/fail9413.d(96): Error: variable `fail9413.foo.baz.y` cannot modify parameter `y` in contract
        y = 10; // err
        ^
fail_compilation/fail9413.d(101): Error: variable `fail9413.foo.x` cannot modify parameter `x` in contract
        x = 10; // err
        ^
fail_compilation/fail9413.d(102): Error: variable `fail9413.foo.r` cannot modify result `r` in contract
        r = 10; // err
        ^
fail_compilation/fail9413.d(103): Error: variable `fail9413.foo.baz.y` cannot modify parameter `y` in contract
        y = 10; // err
        ^
fail_compilation/fail9413.d(104): Error: variable `fail9413.foo.baz.s` cannot modify result `s` in contract
        s = 10; // err
        ^
fail_compilation/fail9413.d(115): Error: variable `fail9413.foo.x` cannot modify parameter `x` in contract
    x = 10; // err
    ^
fail_compilation/fail9413.d(116): Error: variable `fail9413.foo.r` cannot modify result `r` in contract
    r = 10; // err
    ^
---
*/

int foo(int x)
in
{
    int a;
    int bar(int y)
    in
    {
        x = 10; // err
        y = 10; // err
        a = 1;  // OK
    }
    out(s)
    {
        x = 10; // err
        y = 10; // err
        s = 10; // err
        a = 1;  // OK
    }
    do
    {
        x = 10; // err
        y = 1;  // OK
        a = 1;  // OK
        return 2;
    }
    x = 10; // err
}
out(r)
{
    int a;
    int baz(int y)
    in
    {
        x = 10; // err
        r = 10; // err
        y = 10; // err
        a = 1;  // OK
    }
    out(s)
    {
        x = 10; // err
        r = 10; // err
        y = 10; // err
        s = 10; // err
        a = 1;  // OK
    }
    do
    {
        x = 10; // err
        r = 10; // err
        y = 1;  // OK
        a = 1;  // OK
        return 2;
    }
    x = 10; // err
    r = 10; // err
}
do
{
    return 1;
}
