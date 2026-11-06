/*
TEST_OUTPUT:
---
fail_compilation/mixin_version_debug_assign.d-mixin-23(23): Error: version `foo` declaration must be at module level
fail_compilation/mixin_version_debug_assign.d(23):        while parsing string mixin statement
fail_compilation/mixin_version_debug_assign.d-mixin-28(28): Error: debug `bar` declaration must be at module level
fail_compilation/mixin_version_debug_assign.d(28):        while parsing string mixin statement
fail_compilation/mixin_version_debug_assign.d-mixin-33(33): Error: identifier expected, not `1`
fail_compilation/mixin_version_debug_assign.d(33):        while parsing string mixin statement
fail_compilation/mixin_version_debug_assign.d-mixin-38(38): Error: version `foo` declaration must be at module level
fail_compilation/mixin_version_debug_assign.d(38):        while parsing string mixin statement
fail_compilation/mixin_version_debug_assign.d-mixin-43(43): Error: use `.` for member lookup, not `::`
fail_compilation/mixin_version_debug_assign.d(43):        while parsing string mixin statement
fail_compilation/mixin_version_debug_assign.d-mixin-48(48): Error: found `else` without a corresponding `if`, `version` or `debug` statement
fail_compilation/mixin_version_debug_assign.d(48):        while parsing string mixin statement
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

void testIf()
{
    mixin("if (true) version = foo;");
}

void testColonColon()
{
    mixin("a::b;");
}

void testElse()
{
    mixin("else");
}
