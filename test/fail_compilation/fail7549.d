void foo() {}
void foo(int) {}

/*
TEST_OUTPUT:
---
fail_compilation/fail7549.d(13): Error: expression (foo) has ambiguous type
---
*/
void test1()
{
    static assert(is(typeof(foo))); // OK
    typeof(foo)* func_ptr;          // error
}

/*
TEST_OUTPUT:
---
fail_compilation/fail7549.d(30): Error: expression (&c.fun) has ambiguous type
---
*/
void test2()
{
    class C
    {
        int fun(string) { return 1; }
        int fun() { return 1; }
    }
    auto c = new C;
    auto s = typeof(&c.fun).stringof;
}

/*
TEST_OUTPUT:
---
fail_compilation/fail7549.d(42): Error: cannot infer type from overloaded function symbol & foo
fail_compilation/fail7549.d(46): Error: cannot infer return type from ambiguous expression & foo
---
*/
void test3()
{
    auto val1 = &foo;                                    // should be ambiguous
    auto val2 = cast(void function(int))&foo;            // works
    void function(int) val3 = &foo;                      // works

    auto bar1() { return &foo; }                         // should be ambiguous
    auto bar2() { return cast(void function(int))&foo; } // works
    void function(int) bar3() { return &foo; }           // works
}
