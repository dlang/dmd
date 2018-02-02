// PERMUTE_ARGS:
// REQUIRED_ARGS: -conf= -lib

// This test ensures that a library created in D that does not rely on any
// runtime features can be compiled without object.d.  The `-conf=` compiler
// flag ensures the default object.d is not in the import path.

extern(C) int add(int a, int b)
{
    return a + b;
}
