/* TEST_OUTPUT:
---
fail_compilation/test23558.d(103): Error: in expression `__traits(getModuleClasses, S)` `S` must be a module
fail_compilation/test23558.d(105): Error: expected 0 arguments for `getModuleClasses` but had 2
---
 */

// https://issues.dlang.org/show_bug.cgi?id=23558

#line 100

struct S { }

auto x = __traits(getModuleClasses, S);

auto y = __traits(getModuleClasses, 1, 2);
