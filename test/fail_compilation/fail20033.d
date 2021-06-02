// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail20033.d(36): Deprecation: `alias byKeyValue this` is deprecated - This was a bad idea
fail_compilation/fail20033.d(37): Deprecation: `alias byKeyValue this` is deprecated
fail_compilation/fail20033.d(39): Deprecation: `alias byKeyValue this` is deprecated - This was a bad idea
fail_compilation/fail20033.d(40): Deprecation: `alias byKeyValue this` is deprecated
---
*/
#line 1
struct Test {
    import std.typecons : Tuple;
    alias KVT = Tuple!(string, "key", string, "value");

    struct Range {
        bool empty () { return false; }
        KVT front() { return KVT.init; }
        void popFront() {}
    }

    auto byKeyValue () { return Range.init; }

    deprecated("This was a bad idea")
    alias byKeyValue this;
}

struct Test2 {
    import std.typecons : Tuple;
    alias KVT = Tuple!(string, "key", string, "value");

    struct Range {
        bool empty () { return false; }
        KVT front() { return KVT.init; }
        void popFront() {}
    }

    auto byKeyValue () { return Range.init; }

    deprecated alias byKeyValue this;
}

void main ()
{
    foreach (k, v; Test.init.byKeyValue) {} // Fine
    foreach (k, v; Test2.init.byKeyValue) {} // Fine
    foreach (k, v; Test.init) {} // Fails
    foreach (k, v; Test2.init) {} // Fails

    auto f1 = Test.init.front(); // Fails
    auto f2 = Test2.init.front(); // Fails
}
