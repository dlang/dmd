/*
REQUIRED_ARGS:
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/test19961.d(20): Error: `immutable` delegate `test15306.main.__dgliteral1` cannot access mutable data `i`
fail_compilation/test19961.d(28): Error: `const` delegate test15306.main.__dgliteral2 cannot access mutable data `i`
fail_compilation/test19961.d(35): Error: `inout` delegate test15306.main.__dgliteral2 cannot access mutable data `i`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15306
// https://issues.dlang.org/show_bug.cgi?id=19961
void main()
{
    // immutable cannot access mutable
    int i = 42;
    auto dg1 = delegate void() immutable
    {
        i++;
        /*auto inner = i;*/ // incorectly gives error
    };

    // const cannot access mutable
    int* p = &i;
    auto dg2 = delegate int() const
    {
        i++;          // successfully rejected
        //int j = *p; // incorrectly rejected
        return 0;
    };

    auto dg3 = delegate int() inout
    {
        i++;          // successfully rejected
        //int j = *p; // incorrectly rejected
        return 0;
    };
    assert(dg3() == 0);

    // unshared can access shared
    shared j = 43;
    shared int* q = &j;
    auto dg4 = delegate int() { return *q; };
    assert(dg4() == j);
}
