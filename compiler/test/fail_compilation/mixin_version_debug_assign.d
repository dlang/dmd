/*
TEST_OUTPUT:
---
fail_compilation/mixin_version_debug_assign.d-mixin-19(19): Error: version `foo` declaration must be at module level
fail_compilation/mixin_version_debug_assign.d(19):        while parsing string mixin statement
fail_compilation/mixin_version_debug_assign.d-mixin-24(24): Error: debug `bar` declaration must be at module level
fail_compilation/mixin_version_debug_assign.d(24):        while parsing string mixin statement
fail_compilation/mixin_version_debug_assign.d-mixin-29(29): Error: identifier expected, not `1`
fail_compilation/mixin_version_debug_assign.d(29):        while parsing string mixin statement
fail_compilation/mixin_version_debug_assign.d-mixin-34(34): Error: found `else` without a corresponding `if`, `version` or `debug` statement
fail_compilation/mixin_version_debug_assign.d(34):        while parsing string mixin statement
---
*/

// https://github.com/dlang/dmd/issues/23464

void testVersion()
{
    mixin("version = foo;");
}

void testDebug()
{
    mixin("debug = bar;");
}

void testDebugNumber()
{
    mixin("debug = 1;");
}

void testElse()
{
    mixin("else");
}
