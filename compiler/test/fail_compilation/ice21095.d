// https://issues.dlang.org/show_bug.cgi?id=21095
/*
TEST_OUTPUT:
---
fail_compilation/ice21095.d(18): Error: constructor `ice21095.Mutex.__ctor!().this` `in` and `out` contracts can only appear without a body when they are virtual interface functions or abstract
    this()(Object, bool) in { }
    ^
fail_compilation/ice21095.d(16): Error: template instance `ice21095.Mutex.__ctor!()` error instantiating
        this(obj, true);
            ^
---
*/
class Mutex
{
    this(Object obj) {
        this(obj, true);
    }
    this()(Object, bool) in { }
}
