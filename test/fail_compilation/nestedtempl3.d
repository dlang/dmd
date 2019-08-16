/*
TEST_OUTPUT:
---
fail_compilation/nestedtempl3.d(27): Error: cannot access frame pointer of `nestedtempl3.test.S!(i).S`
fail_compilation/nestedtempl3.d(37): Error: static assert:  `0` is false
---
*/

version (DigitalMars)
{

void test()
{
    int i;

    auto f0()
    {
        int j = 10;
        struct S(alias a)
        {
            auto get() { return j; }
        }
        return S!i();
    }

    alias S = typeof(f0());
    auto s = S();
}

}
else
{
    // imitate error output
    pragma(msg, "fail_compilation/nestedtempl3.d(27): Error: cannot access frame pointer of `nestedtempl3.test.S!(i).S`");
}

void func() { static assert(0); }
