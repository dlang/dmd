/*
TEST_OUTPUT:
---
fail_compilation/fail9414a.d(83): Error: variable `fail9414a.C.foo.__require.x` cannot modify parameter `x` in contract
            x = 10; // err
            ^
fail_compilation/fail9414a.d(70): Error: variable `fail9414a.C.foo.__require.x` cannot modify parameter `x` in contract
            x = 10; // err
            ^
fail_compilation/fail9414a.d(71): Error: variable `fail9414a.C.foo.__require.bar.y` cannot modify parameter `y` in contract
            y = 10; // err
            ^
fail_compilation/fail9414a.d(76): Error: variable `fail9414a.C.foo.__require.x` cannot modify parameter `x` in contract
            x = 10; // err
            ^
fail_compilation/fail9414a.d(77): Error: variable `fail9414a.C.foo.__require.bar.y` cannot modify parameter `y` in contract
            y = 10; // err
            ^
fail_compilation/fail9414a.d(78): Error: variable `fail9414a.C.foo.__require.bar.s` cannot modify result `s` in contract
            s = 10; // err
            ^
fail_compilation/fail9414a.d(88): Error: variable `fail9414a.C.foo.__require.x` cannot modify parameter `x` in contract
        x = 10; // err
        ^
fail_compilation/fail9414a.d(111): Error: variable `fail9414a.C.foo.__ensure.x` cannot modify result `x` in contract
            x = 10; // err
            ^
fail_compilation/fail9414a.d(112): Error: variable `fail9414a.C.foo.__ensure.r` cannot modify result `r` in contract
            r = 10; // err
            ^
fail_compilation/fail9414a.d(96): Error: variable `fail9414a.C.foo.__ensure.x` cannot modify result `x` in contract
            x = 10; // err
            ^
fail_compilation/fail9414a.d(97): Error: variable `fail9414a.C.foo.__ensure.r` cannot modify result `r` in contract
            r = 10; // err
            ^
fail_compilation/fail9414a.d(98): Error: variable `fail9414a.C.foo.__ensure.baz.y` cannot modify parameter `y` in contract
            y = 10; // err
            ^
fail_compilation/fail9414a.d(103): Error: variable `fail9414a.C.foo.__ensure.x` cannot modify result `x` in contract
            x = 10; // err
            ^
fail_compilation/fail9414a.d(104): Error: variable `fail9414a.C.foo.__ensure.r` cannot modify result `r` in contract
            r = 10; // err
            ^
fail_compilation/fail9414a.d(105): Error: variable `fail9414a.C.foo.__ensure.baz.y` cannot modify parameter `y` in contract
            y = 10; // err
            ^
fail_compilation/fail9414a.d(106): Error: variable `fail9414a.C.foo.__ensure.baz.s` cannot modify result `s` in contract
            s = 10; // err
            ^
fail_compilation/fail9414a.d(117): Error: variable `fail9414a.C.foo.__ensure.x` cannot modify result `x` in contract
        x = 10; // err
        ^
fail_compilation/fail9414a.d(118): Error: variable `fail9414a.C.foo.__ensure.r` cannot modify result `r` in contract
        r = 10; // err
        ^
---
*/

class C
{
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
}
