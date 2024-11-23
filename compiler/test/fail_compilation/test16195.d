/*
 * TEST_OUTPUT:
---
fail_compilation/test16195.d(16): Error: the `delete` keyword is obsolete
    delete p;
    ^
fail_compilation/test16195.d(16):        use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead
---
 */


// https://issues.dlang.org/show_bug.cgi?id=16195

@safe pure nothrow @nogc void test(int* p)
{
    delete p;
}
