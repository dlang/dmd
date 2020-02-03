/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/issue12931.d(103): Deprecation: Using `const` on the left hand side of a declaration is deprecated. Move `const` to the right hand side of the function.
fail_compilation/issue12931.d(104): Deprecation: Using `immutable` on the left hand side of a declaration is deprecated. Move `immutable` to the right hand side of the function.
fail_compilation/issue12931.d(105): Deprecation: Using `shared` on the left hand side of a declaration is deprecated. Move `shared` to the right hand side of the function.
fail_compilation/issue12931.d(106): Deprecation: Using `inout` on the left hand side of a declaration is deprecated. Move `inout` to the right hand side of the function.
fail_compilation/issue12931.d(111): Deprecation: Using `const` on the left hand side of a declaration is deprecated. Move `const` to the right hand side of the function.
fail_compilation/issue12931.d(112): Deprecation: Using `immutable` on the left hand side of a declaration is deprecated. Move `immutable` to the right hand side of the function.
fail_compilation/issue12931.d(113): Deprecation: Using `shared` on the left hand side of a declaration is deprecated. Move `shared` to the right hand side of the function.
fail_compilation/issue12931.d(114): Deprecation: Using `inout` on the left hand side of a declaration is deprecated. Move `inout` to the right hand side of the function.
---
*/
#line 100

class Foo
{
    const int constMeth () { assert(0); }
    immutable int immutableMeth () { assert(0); }
    shared int sharedMeth () { assert(0); }
    inout int inoutMeth (inout(string) arg) { assert(0); }
}

struct Bar
{
    const int constMeth () { assert(0); }
    immutable int immutableMeth () { assert(0); }
    shared int sharedMeth () { assert(0); }
    inout int inoutMeth (inout(string) arg) { assert(0); }
}
