// DISABLED: linux osx freebsd dragonflybsd netbsd

// Windows only
version (Windows) {}
else static assert(0);

/*
TEST_OUTPUT:
---
fail_compilation/fail4082win.d(5): Error: destructor `fail4082win.Bar.~this` is not `nothrow`
fail_compilation/fail4082win.d(5): Error: `nothrow` function `fail4082win.test2` may throw
---
*/

#line 1
struct Bar
{
    ~this() { throw new Exception(""); }
}
nothrow void test2(Bar t)
{
}
