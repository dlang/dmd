/* TEST_OUTPUT:
---
fail_compilation/test19646.d(16): Error: cast from `const(int)*` to `int*` not allowed in safe code
int* y = cast(int*)&x;
         ^
fail_compilation/test19646.d(16):        Source type is incompatible with target type containing a pointer
fail_compilation/test19646.d(22): Error: `@safe` variable `z` cannot be initialized by calling `@system` function `f`
@safe int* z = f();
                ^
---
https://issues.dlang.org/show_bug.cgi?id=19646
 */

@safe:
const x = 42;
int* y = cast(int*)&x;

@system:

@system int* f() { return cast(int*) 0xDEADBEEF; };

@safe int* z = f();
