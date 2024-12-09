/*
REQUIRED_ARGS: -preview=systemVariables
TEST_OUTPUT:
---
fail_compilation/systemvariables_var_init.d(36): Error: cannot access `@system` variable `ptrEnum` in @safe code
    *ptrEnum = 0;
     ^
fail_compilation/systemvariables_var_init.d(28):        `ptrEnum` is inferred to be `@system` from its initializer here
enum uint* ptrEnum = cast(uint*) 0xC00000;
           ^
fail_compilation/systemvariables_var_init.d(37): Error: cannot access `@system` variable `ptrConst` in @safe code
    *ptrConst = 0;
     ^
fail_compilation/systemvariables_var_init.d(29):        `ptrConst` is inferred to be `@system` from its initializer here
const uint* ptrConst = cast(uint*) 0xC00000;
            ^
fail_compilation/systemvariables_var_init.d(39): Error: cannot access `@system` variable `ptrVar` in @safe code
    *ptrVar = 0;
     ^
fail_compilation/systemvariables_var_init.d(31):        `ptrVar` is inferred to be `@system` from its initializer here
uint* ptrVar = cast(uint*) 0xC00000;
      ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=24051

enum uint* ptrEnum = cast(uint*) 0xC00000;
const uint* ptrConst = cast(uint*) 0xC00000;
uint* ptrVarSafe = null;
uint* ptrVar = cast(uint*) 0xC00000;
@trusted uint* ptrTrusted = cast(uint*) 0xC00000;

void varInitializers() @safe
{
    *ptrEnum = 0;
    *ptrConst = 0;
    *ptrVarSafe = 0;
    *ptrVar = 0;
    *ptrTrusted = 0;
}
