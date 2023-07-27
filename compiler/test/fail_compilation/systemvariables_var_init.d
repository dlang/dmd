/*
REQUIRED_ARGS: -preview=systemVariables
TEST_OUTPUT:
---
fail_compilation/systemvariables_var_init.d(21): Error: cannot access `@system` variable `ptrEnum` in @safe code
fail_compilation/systemvariables_var_init.d(22): Error: cannot access `@system` variable `ptrConst` in @safe code
fail_compilation/systemvariables_var_init.d(24): Error: cannot access `@system` variable `ptrVar` in @safe code
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
