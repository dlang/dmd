/*
TEST_OUTPUT:
---
fail_compilation/fail9414a.d(47): Error: variable `fail9414a.C.foo.__require.x` cannot modify parameter `x` in contract
fail_compilation/fail9414a.d(34): Error: variable `fail9414a.C.foo.__require.x` cannot modify parameter `x` in contract
fail_compilation/fail9414a.d(35): Error: variable `fail9414a.C.foo.__require.bar.y` cannot modify parameter `y` in contract
fail_compilation/fail9414a.d(40): Error: variable `fail9414a.C.foo.__require.x` cannot modify parameter `x` in contract
fail_compilation/fail9414a.d(41): Error: variable `fail9414a.C.foo.__require.bar.y` cannot modify parameter `y` in contract
fail_compilation/fail9414a.d(42): Error: variable `fail9414a.C.foo.__require.bar.s` cannot modify result `s` in contract
fail_compilation/fail9414a.d(52): Error: variable `fail9414a.C.foo.__require.x` cannot modify parameter `x` in contract
fail_compilation/fail9414a.d(75): Error: variable `fail9414a.C.foo.__ensure.x` cannot modify result `x` in contract
fail_compilation/fail9414a.d(76): Error: variable `fail9414a.C.foo.__ensure.r` cannot modify result `r` in contract
fail_compilation/fail9414a.d(60): Error: variable `fail9414a.C.foo.__ensure.x` cannot modify result `x` in contract
fail_compilation/fail9414a.d(61): Error: variable `fail9414a.C.foo.__ensure.r` cannot modify result `r` in contract
fail_compilation/fail9414a.d(62): Error: variable `fail9414a.C.foo.__ensure.baz.y` cannot modify parameter `y` in contract
fail_compilation/fail9414a.d(67): Error: variable `fail9414a.C.foo.__ensure.x` cannot modify result `x` in contract
fail_compilation/fail9414a.d(68): Error: variable `fail9414a.C.foo.__ensure.r` cannot modify result `r` in contract
fail_compilation/fail9414a.d(69): Error: variable `fail9414a.C.foo.__ensure.baz.y` cannot modify parameter `y` in contract
fail_compilation/fail9414a.d(70): Error: variable `fail9414a.C.foo.__ensure.baz.s` cannot modify result `s` in contract
fail_compilation/fail9414a.d(81): Error: variable `fail9414a.C.foo.__ensure.x` cannot modify result `x` in contract
fail_compilation/fail9414a.d(82): Error: variable `fail9414a.C.foo.__ensure.r` cannot modify result `r` in contract
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
