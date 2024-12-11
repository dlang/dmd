

// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/ice11822.d(41): Deprecation: function `ice11822.d` is deprecated
    return g!(n => d(i))();
                    ^
fail_compilation/ice11822.d(24):        instantiated from here: `__lambda_L41_C15!int`
    this(int) { pred(1); }
                    ^
fail_compilation/ice11822.d(30):        instantiated from here: `S!(__lambda_L41_C15)`
    return S!pred(3);
           ^
fail_compilation/ice11822.d(41):        instantiated from here: `g!((n) => d(i))`
    return g!(n => d(i))();
           ^
---
*/

struct S(alias pred)
{
    this(int) { pred(1); }
    void f()  { pred(2); }
}

auto g(alias pred)()
{
    return S!pred(3);
}

deprecated bool d(int)
{
    return true;
}

auto h()
{
    int i;
    return g!(n => d(i))();
}
