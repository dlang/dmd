/*
TEST_OUTPUT:
---
fail_compilation/ctfe10995.d(21): Error: cannot read uninitialized variable `a` in CTFE
fail_compilation/ctfe10995.d(27): Error: cannot read uninitialized variable `a` in CTFE
fail_compilation/ctfe10995.d(30): Error: cannot read uninitialized variable `g` in CTFE
fail_compilation/ctfe10995.d(31):        called from here: `bar()`
---
*/
struct T
{
    short a = void;
}

T foo()
{
    auto t = T.init;
    return t;
}

enum i = foo().a;

struct T2
{
    short a = void;
}
enum i2 = T2.init.a;

immutable int g = void;
int bar() { return g; }
enum i3 = bar();
