/*
TEST_OUTPUT:
---
fail_compilation/fail9766.d(15): Error: declaration expected, not `^`
---
^
fail_compilation/fail9766.d(17): Error: alignment must be an integer positive power of 2, not 0xffffffffffffffff
#line 12
^
fail_compilation/fail9766.d(20): Error: alignment must be an integer positive power of 2, not 0x0
align(Foo!int)
^
fail_compilation/fail9766.d(23): Error: alignment must be an integer positive power of 2, not 0x3
*/
^
fail_compilation/fail9766.d(26): Error: alignment must be an integer positive power of 2, not 0x80000001
template Foo(T) {}
^
---
^
fail_compilation/fail9766.d(23): Error: alignment must be an integer positive power of 2, not 0x3
#line 12
^
fail_compilation/fail9766.d(26): Error: alignment must be an integer positive power of 2, not 0x80000001
align(Foo!int)
^
---
*/

#line 12
template Foo(T) {}

align(Foo!int)
struct S9766a {}

align(-1)
struct S9766b {}

align(0)
struct S9766c {}

align(3)
struct S9766d {}

align((1u << 31) + 1)
struct S9766e {}
