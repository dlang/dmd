// DISABLED: win

// POSIX only
version (Posix) {}
else static assert(0);

/*
TEST_OUTPUT:
---
fail_compilation/fail4082posix.d(7): Error: destructor `fail4082posix.Bar.~this` is not `nothrow`
fail_compilation/fail4082posix.d(5): Error: `nothrow` function `fail4082posix.test` may throw
---
*/

#line 1
struct Bar
{
    ~this() { throw new Exception(""); }
}
nothrow void test()
{
    test2(Bar.init);
}
nothrow void test2(Bar t)
{
}
