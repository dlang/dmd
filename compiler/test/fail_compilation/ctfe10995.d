/*
TEST_OUTPUT:
---
fail_compilation/ctfe10995.d(23): Error: cannot read uninitialized variable `a` in CTFE
enum i = foo().a;
            ^
fail_compilation/ctfe10995.d(29): Error: cannot read uninitialized variable `a` in CTFE
enum i2 = T2.init.a;
          ^
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
