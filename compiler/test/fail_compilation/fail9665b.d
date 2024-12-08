/***************************************************/
// with disable this() struct

struct X
{
    @disable this();

    this(int) {}
}

/+
TEST_OUTPUT:
---
fail_compilation/fail9665b.d(65): Error: one path skips field `x2`
        if (true) x2 = X(1);
        ^
fail_compilation/fail9665b.d(66): Error: one path skips field `x3`
        auto n = true ? (x3 = X(1)) : X.init;
                 ^
fail_compilation/fail9665b.d(68): Error: one path skips field `x5`
        if (true) x5 = X(1);
        ^
fail_compilation/fail9665b.d(69): Error: one path skips field `x6`
        auto m = true ? (x6 = X(1)) : typeof(x6).init;
                 ^
fail_compilation/fail9665b.d(63): Error: field `x1` must be initialized in constructor
    this(int)
    ^
fail_compilation/fail9665b.d(63): Error: field `x4` must be initialized in constructor
    this(int)
    ^
fail_compilation/fail9665b.d(86): Error: one path skips field `x2`
        if (true) x2 = x;
        ^
fail_compilation/fail9665b.d(87): Error: one path skips field `x3`
        auto a = true ? (x3 = x) : X.init;
                 ^
fail_compilation/fail9665b.d(89): Error: one path skips field `x5`
        if (true) x5 = x;
        ^
fail_compilation/fail9665b.d(90): Error: one path skips field `x6`
        auto b = true ? (x6 = x) : typeof(x6).init;
                 ^
fail_compilation/fail9665b.d(84): Error: field `x1` must be initialized in constructor, because it is nested struct
    this(X x)
    ^
fail_compilation/fail9665b.d(84): Error: field `x4` must be initialized in constructor, because it is nested struct
    this(X x)
    ^
fail_compilation/fail9665b.d(97): Error: template instance `fail9665b.S2!(X)` error instantiating
    S2!(X) s = X(1);
    ^
---
+/
struct S1
{
    X x1;
    X x2;
    X x3;
    X[2] x4;
    X[2] x5;
    X[2] x6;
    this(int)
    {
        if (true) x2 = X(1);
        auto n = true ? (x3 = X(1)) : X.init;

        if (true) x5 = X(1);
        auto m = true ? (x6 = X(1)) : typeof(x6).init;
    }
}

/***************************************************/
// with nested struct

struct S2(X)
{
    X x1;
    X x2;
    X x3;
    X[2] x4;
    X[2] x5;
    X[2] x6;
    this(X x)
    {
        if (true) x2 = x;
        auto a = true ? (x3 = x) : X.init;

        if (true) x5 = x;
        auto b = true ? (x6 = x) : typeof(x6).init;
    }
}
void test2()
{
    struct X { this(int) {} }
    static assert(X.tupleof.length == 1);
    S2!(X) s = X(1);
}
