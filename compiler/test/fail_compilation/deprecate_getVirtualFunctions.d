// REQUIRED_ARGS: -de

/*
TEST_OUTPUT:
---
fail_compilation/deprecate_getVirtualFunctions.d(22): Deprecation: `traits(isVirtualFunction)` is deprecated. Use `traits(isVirtualMethod)` instead
    auto a = __traits(isVirtualFunction, A.fun);
             ^
fail_compilation/deprecate_getVirtualFunctions.d(23): Deprecation: `traits(getVirtualFunctions)` is deprecated. Use `traits(getVirtualMethods)` instead
    foreach(f; __traits(getVirtualFunctions, A, "fun")) {}
               ^
---
*/

class A
{
    void fun() {}
}

void main()
{
    auto a = __traits(isVirtualFunction, A.fun);
    foreach(f; __traits(getVirtualFunctions, A, "fun")) {}
}
