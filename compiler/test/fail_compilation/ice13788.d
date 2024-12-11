/*
TEST_OUTPUT:
---
fail_compilation/ice13788.d(19): Error: pragma `mangle` - string expected for mangled name
pragma(mangle) void f1();
^
fail_compilation/ice13788.d(20): Error: `string` expected for mangled name, not `(1)` of type `int`
pragma(mangle, 1) void f2();
               ^
fail_compilation/ice13788.d(21): Error: pragma `mangle` - zero-length string not allowed for mangled name
pragma(mangle, "") void f3();
^
fail_compilation/ice13788.d(22): Error: pragma `mangle` - mangled name characters can only be of type `char`
pragma(mangle, "a"w) void f4();
^
---
*/

pragma(mangle) void f1();
pragma(mangle, 1) void f2();
pragma(mangle, "") void f3();
pragma(mangle, "a"w) void f4();
