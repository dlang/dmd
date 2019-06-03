/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/depcpp.d(9): Deprecation: Scoped version of `extern(C++, namespace)` is deprecated. Use `extern(C++, "std")` instead.
---
*/

extern (C++, std)
{
    struct vector (T) { T*[3] ptrs; }
}

void main ()
{
    std.vector!int foo;
}
